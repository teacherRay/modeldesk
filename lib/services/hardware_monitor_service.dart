import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import '../models/hardware_telemetry.dart';

// --- Native Structs ---

final class MemoryStatusEx extends Struct {
  @Uint32()
  external int dwLength;

  @Uint32()
  external int dwMemoryLoad;

  @Uint64()
  external int ullTotalPhys;

  @Uint64()
  external int ullAvailPhys;

  @Uint64()
  external int ullTotalPageFile;

  @Uint64()
  external int ullAvailPageFile;

  @Uint64()
  external int ullTotalVirtual;

  @Uint64()
  external int ullAvailVirtual;

  @Uint64()
  external int ullAvailExtendedVirtual;
}

final class FileTime extends Struct {
  @Uint32()
  external int dwLowDateTime;

  @Uint32()
  external int dwHighDateTime;

  int toInt() => (dwHighDateTime << 32) | dwLowDateTime;
}

final class ProcessMemoryCounters extends Struct {
  @Uint32()
  external int cb;

  @Uint32()
  external int pageFaultCount;

  @Size()
  external int peakWorkingSetSize;

  @Size()
  external int workingSetSize;

  @Size()
  external int quotaPeakPagedPoolUsage;

  @Size()
  external int quotaPagedPoolUsage;

  @Size()
  external int quotaPeakNonPagedPoolUsage;

  @Size()
  external int quotaNonPagedPoolUsage;

  @Size()
  external int pagefileUsage;

  @Size()
  external int peakPagefileUsage;
}

final class DxgiAdapterDesc extends Struct {
  @Array(128)
  external Array<Uint16> description;

  @Uint32()
  external int vendorId;

  @Uint32()
  external int deviceId;

  @Uint32()
  external int subSysId;

  @Uint32()
  external int revision;

  @Size()
  external int dedicatedVideoMemory;

  @Size()
  external int dedicatedSystemMemory;

  @Size()
  external int sharedSystemMemory;

  @Int64()
  external int adapterLuid;
}

final class Guid extends Struct {
  @Uint32()
  external int data1;

  @Uint16()
  external int data2;

  @Uint16()
  external int data3;

  @Array(8)
  external Array<Uint8> data4;
}

final class AdlSingleSensorData extends Struct {
  @Int32()
  external int supported;

  @Int32()
  external int value;
}

final class AdlPmLogDataOutput extends Struct {
  @Int32()
  external int iSize;

  @Array(256)
  external Array<AdlSingleSensorData> sensors;
}

// --- Native Signatures ---

typedef GlobalMemoryStatusExNative = Int32 Function(Pointer<MemoryStatusEx>);
typedef GlobalMemoryStatusExDart = int Function(Pointer<MemoryStatusEx>);

typedef GetSystemTimesNative = Int32 Function(Pointer<FileTime>, Pointer<FileTime>, Pointer<FileTime>);
typedef GetSystemTimesDart = int Function(Pointer<FileTime>, Pointer<FileTime>, Pointer<FileTime>);

typedef OpenProcessNative = IntPtr Function(Uint32, Int32, Uint32);
typedef OpenProcessDart = int Function(int, int, int);

typedef CloseHandleNative = Int32 Function(IntPtr);
typedef CloseHandleDart = int Function(int);

typedef GetProcessTimesNative = Int32 Function(
    IntPtr, Pointer<FileTime>, Pointer<FileTime>, Pointer<FileTime>, Pointer<FileTime>);
typedef GetProcessTimesDart = int Function(
    int, Pointer<FileTime>, Pointer<FileTime>, Pointer<FileTime>, Pointer<FileTime>);

typedef K32GetProcessMemoryInfoNative = Int32 Function(IntPtr, Pointer<ProcessMemoryCounters>, Uint32);
typedef K32GetProcessMemoryInfoDart = int Function(int, Pointer<ProcessMemoryCounters>, int);

typedef CreateDxgiFactoryNative = Int32 Function(Pointer<Guid>, Pointer<Pointer<IntPtr>>);
typedef CreateDxgiFactoryDart = int Function(Pointer<Guid>, Pointer<Pointer<IntPtr>>);

typedef EnumAdaptersNative = Int32 Function(Pointer<IntPtr>, Uint32, Pointer<Pointer<IntPtr>>);
typedef EnumAdaptersDart = int Function(Pointer<IntPtr>, int, Pointer<Pointer<IntPtr>>);

typedef GetDescNative = Int32 Function(Pointer<IntPtr>, Pointer<DxgiAdapterDesc>);
typedef GetDescDart = int Function(Pointer<IntPtr>, Pointer<DxgiAdapterDesc>);

typedef ReleaseNative = Uint32 Function(Pointer<IntPtr>);
typedef ReleaseDart = int Function(Pointer<IntPtr>);

typedef AdlMainControlCreateNative = Int32 Function(Pointer<Void>, Int32);
typedef AdlMainControlCreateDart = int Function(Pointer<Void>, int);

typedef Adl2NewQueryPmLogDataGetNative = Int32 Function(Pointer<Void>, Int32, Pointer<AdlPmLogDataOutput>);
typedef Adl2NewQueryPmLogDataGetDart = int Function(Pointer<Void>, int, Pointer<AdlPmLogDataOutput>);

class HardwareMonitorService {
  DynamicLibrary? _kernel32;
  DynamicLibrary? _psapi;
  DynamicLibrary? _adl;

  GlobalMemoryStatusExDart? _globalMemoryStatusEx;
  GetSystemTimesDart? _getSystemTimes;
  OpenProcessDart? _openProcess;
  CloseHandleDart? _closeHandle;
  GetProcessTimesDart? _getProcessTimes;
  K32GetProcessMemoryInfoDart? _k32GetProcessMemoryInfo;

  Adl2NewQueryPmLogDataGetDart? _adlQueryPmLog;
  bool _adlAvailable = false;

  String _gpuName = 'GPU';
  int _dedicatedVramTotalBytes = 16 * 1024 * 1024 * 1024; // Default 16 GB fallback

  // CPU calculation state
  int _prevIdleTime = 0;
  int _prevKernelTime = 0;
  int _prevUserTime = 0;

  // Process CPU calculation state
  int _prevProcKernelTime = 0;
  int _prevProcUserTime = 0;
  int _prevProcSystemTime = 0;
  int? _trackedPid;

  Timer? _pollingTimer;
  final StreamController<HardwareTelemetry> _telemetryController =
      StreamController<HardwareTelemetry>.broadcast();

  Stream<HardwareTelemetry> get telemetryStream => _telemetryController.stream;
  String get gpuName => _gpuName;
  int get dedicatedVramTotalBytes => _dedicatedVramTotalBytes;
  bool get isAdlAvailable => _adlAvailable;

  HardwareMonitorService() {
    if (Platform.isWindows) {
      _initWindowsApis();
      _initDxgi();
      _initAdl();
    }
  }

  void _initWindowsApis() {
    try {
      _kernel32 = DynamicLibrary.open('kernel32.dll');
      _globalMemoryStatusEx = _kernel32!
          .lookupFunction<GlobalMemoryStatusExNative, GlobalMemoryStatusExDart>('GlobalMemoryStatusEx');
      _getSystemTimes = _kernel32!
          .lookupFunction<GetSystemTimesNative, GetSystemTimesDart>('GetSystemTimes');
      _openProcess = _kernel32!
          .lookupFunction<OpenProcessNative, OpenProcessDart>('OpenProcess');
      _closeHandle = _kernel32!
          .lookupFunction<CloseHandleNative, CloseHandleDart>('CloseHandle');
      _getProcessTimes = _kernel32!
          .lookupFunction<GetProcessTimesNative, GetProcessTimesDart>('GetProcessTimes');

      try {
        _k32GetProcessMemoryInfo = _kernel32!
            .lookupFunction<K32GetProcessMemoryInfoNative, K32GetProcessMemoryInfoDart>('K32GetProcessMemoryInfo');
      } catch (_) {
        _psapi = DynamicLibrary.open('psapi.dll');
        _k32GetProcessMemoryInfo = _psapi!
            .lookupFunction<K32GetProcessMemoryInfoNative, K32GetProcessMemoryInfoDart>('GetProcessMemoryInfo');
      }

      // Initialize system times baseline
      final idle = calloc<FileTime>();
      final kernel = calloc<FileTime>();
      final user = calloc<FileTime>();
      if (_getSystemTimes!(idle, kernel, user) != 0) {
        _prevIdleTime = idle.ref.toInt();
        _prevKernelTime = kernel.ref.toInt();
        _prevUserTime = user.ref.toInt();
      }
      calloc.free(idle);
      calloc.free(kernel);
      calloc.free(user);
    } catch (_) {}
  }

  void _initDxgi() {
    try {
      final dxgi = DynamicLibrary.open('dxgi.dll');
      final createFactory = dxgi
          .lookupFunction<CreateDxgiFactoryNative, CreateDxgiFactoryDart>('CreateDXGIFactory');

      final iid = calloc<Guid>();
      iid.ref.data1 = 0x7b7166ec;
      iid.ref.data2 = 0x21c7;
      iid.ref.data3 = 0x44ae;
      final bytes = [0xb2, 0x1a, 0xc9, 0xae, 0x32, 0x1a, 0xe3, 0x69];
      for (int i = 0; i < 8; i++) {
        iid.ref.data4[i] = bytes[i];
      }

      final pFactory = calloc<Pointer<IntPtr>>();
      if (createFactory(iid, pFactory) == 0 && pFactory.value != nullptr) {
        final factory = pFactory.value;
        final factoryVtbl = factory.cast<Pointer<IntPtr>>().value;
        final enumAdaptersPtr = Pointer<NativeFunction<EnumAdaptersNative>>.fromAddress(
            (factoryVtbl + 7).value);
        final enumAdapters = enumAdaptersPtr.asFunction<EnumAdaptersDart>();
        final releaseFactoryPtr = Pointer<NativeFunction<ReleaseNative>>.fromAddress(
            (factoryVtbl + 2).value);
        final releaseFactory = releaseFactoryPtr.asFunction<ReleaseDart>();

        int adapterIndex = 0;
        while (true) {
          final pAdapter = calloc<Pointer<IntPtr>>();
          if (enumAdapters(factory, adapterIndex, pAdapter) != 0 || pAdapter.value == nullptr) {
            calloc.free(pAdapter);
            break;
          }

          final adapter = pAdapter.value;
          final adapterVtbl = adapter.cast<Pointer<IntPtr>>().value;
          final getDescPtr = Pointer<NativeFunction<GetDescNative>>.fromAddress(
              (adapterVtbl + 8).value);
          final getDesc = getDescPtr.asFunction<GetDescDart>();
          final releaseAdapterPtr = Pointer<NativeFunction<ReleaseNative>>.fromAddress(
              (adapterVtbl + 2).value);
          final releaseAdapter = releaseAdapterPtr.asFunction<ReleaseDart>();

          final desc = calloc<DxgiAdapterDesc>();
          if (getDesc(adapter, desc) == 0) {
            final chars = <int>[];
            for (int i = 0; i < 128; i++) {
              final c = desc.ref.description[i];
              if (c == 0) break;
              chars.add(c);
            }
            final name = String.fromCharCodes(chars).trim();
            final vramBytes = desc.ref.dedicatedVideoMemory;

            // Select discrete GPU (ignoring Microsoft Basic Render Driver)
            if (!name.contains('Basic Render') && vramBytes > 0) {
              _gpuName = name;
              _dedicatedVramTotalBytes = vramBytes;
              calloc.free(desc);
              releaseAdapter(adapter);
              calloc.free(pAdapter);
              break;
            } else if (adapterIndex == 0 && name.isNotEmpty) {
              _gpuName = name;
              if (vramBytes > 0) _dedicatedVramTotalBytes = vramBytes;
            }
          }

          calloc.free(desc);
          releaseAdapter(adapter);
          calloc.free(pAdapter);
          adapterIndex++;
        }

        releaseFactory(factory);
      }

      calloc.free(pFactory);
      calloc.free(iid);
    } catch (_) {}
  }

  void _initAdl() {
    try {
      final msvcrt = DynamicLibrary.open('msvcrt.dll');
      final mallocPtr = msvcrt.lookup<Void>('malloc');

      _adl = DynamicLibrary.open('atiadlxx.dll');
      final adlCreate = _adl!
          .lookupFunction<AdlMainControlCreateNative, AdlMainControlCreateDart>('ADL_Main_Control_Create');
      final res = adlCreate(mallocPtr, 1);
      if (res == 0) {
        _adlQueryPmLog = _adl!.lookupFunction<Adl2NewQueryPmLogDataGetNative,
            Adl2NewQueryPmLogDataGetDart>('ADL2_New_QueryPMLogData_Get');
        _adlAvailable = true;
      }
    } catch (_) {
      _adlAvailable = false;
    }
  }

  HardwareTelemetry sample({int? llamaPid}) {
    if (!Platform.isWindows) {
      return HardwareTelemetry.empty();
    }

    final cpu = _sampleCpu(llamaPid: llamaPid);
    final ram = _sampleRam(llamaPid: llamaPid);
    final gpu = _sampleGpu();

    return HardwareTelemetry(
      timestamp: DateTime.now(),
      cpu: cpu,
      ram: ram,
      gpu: gpu,
    );
  }

  CpuTelemetry _sampleCpu({int? llamaPid}) {
    double cpuPercent = 0.0;
    final cores = Platform.numberOfProcessors;

    if (_getSystemTimes != null) {
      final idle = calloc<FileTime>();
      final kernel = calloc<FileTime>();
      final user = calloc<FileTime>();

      if (_getSystemTimes!(idle, kernel, user) != 0) {
        final idleNow = idle.ref.toInt();
        final kernelNow = kernel.ref.toInt();
        final userNow = user.ref.toInt();

        final dIdle = idleNow - _prevIdleTime;
        final dKernel = kernelNow - _prevKernelTime;
        final dUser = userNow - _prevUserTime;
        final dTotal = dKernel + dUser;

        if (dTotal > 0) {
          final usage = (1.0 - (dIdle / dTotal)) * 100.0;
          cpuPercent = usage.clamp(0.0, 100.0);
        }

        _prevIdleTime = idleNow;
        _prevKernelTime = kernelNow;
        _prevUserTime = userNow;
      }

      calloc.free(idle);
      calloc.free(kernel);
      calloc.free(user);
    }

    // Process specific CPU
    double? llamaCpu;
    if (llamaPid != null && llamaPid > 0 && _openProcess != null && _getProcessTimes != null) {
      llamaCpu = _sampleProcessCpu(llamaPid);
    }

    return CpuTelemetry(
      percent: cpuPercent,
      logicalCores: cores,
      clockGhz: 'Auto',
      llamaCpuPercent: llamaCpu,
    );
  }

  double? _sampleProcessCpu(int pid) {
    // PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
    final hProcess = _openProcess!(0x1000, 0, pid);
    if (hProcess == 0) return null;

    try {
      final creation = calloc<FileTime>();
      final exit = calloc<FileTime>();
      final kernel = calloc<FileTime>();
      final user = calloc<FileTime>();

      double? result;
      if (_getProcessTimes!(hProcess, creation, exit, kernel, user) != 0) {
        final kTime = kernel.ref.toInt();
        final uTime = user.ref.toInt();
        final nowSystem = DateTime.now().microsecondsSinceEpoch * 10; // in 100ns units

        if (_trackedPid == pid && _prevProcSystemTime > 0) {
          final dProcTime = (kTime - _prevProcKernelTime) + (uTime - _prevProcUserTime);
          final dSysTime = nowSystem - _prevProcSystemTime;
          if (dSysTime > 0) {
            final val = (dProcTime / dSysTime) * 100.0;
            result = val.clamp(0.0, 100.0 * Platform.numberOfProcessors);
          }
        }

        _trackedPid = pid;
        _prevProcKernelTime = kTime;
        _prevProcUserTime = uTime;
        _prevProcSystemTime = nowSystem;
      }

      calloc.free(creation);
      calloc.free(exit);
      calloc.free(kernel);
      calloc.free(user);
      return result;
    } finally {
      _closeHandle?.call(hProcess);
    }
  }

  RamTelemetry _sampleRam({int? llamaPid}) {
    int totalBytes = 16 * 1024 * 1024 * 1024;
    int usedBytes = 0;
    int freeBytes = 0;
    double percent = 0.0;

    if (_globalMemoryStatusEx != null) {
      final mem = calloc<MemoryStatusEx>();
      mem.ref.dwLength = sizeOf<MemoryStatusEx>();
      if (_globalMemoryStatusEx!(mem) != 0) {
        totalBytes = mem.ref.ullTotalPhys;
        freeBytes = mem.ref.ullAvailPhys;
        usedBytes = totalBytes - freeBytes;
        percent = mem.ref.dwMemoryLoad.toDouble();
      }
      calloc.free(mem);
    }

    // Process specific RAM (working set)
    int? llamaRam;
    if (llamaPid != null && llamaPid > 0 && _openProcess != null && _k32GetProcessMemoryInfo != null) {
      final hProcess = _openProcess!(0x1000 | 0x0010, 0, pidToUint(llamaPid));
      if (hProcess != 0) {
        try {
          final counters = calloc<ProcessMemoryCounters>();
          counters.ref.cb = sizeOf<ProcessMemoryCounters>();
          if (_k32GetProcessMemoryInfo!(hProcess, counters, counters.ref.cb) != 0) {
            llamaRam = counters.ref.workingSetSize;
          }
          calloc.free(counters);
        } finally {
          _closeHandle?.call(hProcess);
        }
      }
    }

    return RamTelemetry(
      usedBytes: usedBytes,
      totalBytes: totalBytes,
      freeBytes: freeBytes,
      percent: percent,
      llamaRamBytes: llamaRam,
    );
  }

  GpuTelemetry _sampleGpu() {
    double utilPercent = 0.0;
    int vramUsedBytes = 0;
    int? tempEdge;
    int? tempHotspot;
    int? tempMem;
    int? fanSpeed;
    int? powerWatts;
    int? gfxClock;
    int? memClock;

    if (_adlAvailable && _adlQueryPmLog != null) {
      final out = calloc<AdlPmLogDataOutput>();
      out.ref.iSize = sizeOf<AdlPmLogDataOutput>();
      try {
        if (_adlQueryPmLog!(nullptr, 0, out) == 0) {
          final s = out.ref.sensors;
          // SENSOR_ACTIVITY_GFX = 19
          if (s[19].supported == 1) {
            utilPercent = s[19].value.toDouble().clamp(0.0, 100.0);
          }
          // SENSOR_VRAM_USED_MB = 21
          if (s[21].supported == 1 && s[21].value > 0) {
            vramUsedBytes = s[21].value * 1024 * 1024;
          }
          // SENSOR_TEMP_EDGE = 8
          if (s[8].supported == 1) tempEdge = s[8].value;
          // SENSOR_TEMP_HOTSPOT = 9
          if (s[9].supported == 1) tempHotspot = s[9].value;
          // SENSOR_TEMP_MEM = 27
          if (s[27].supported == 1) tempMem = s[27].value;
          // SENSOR_FAN_PERCENT = 40
          if (s[40].supported == 1) fanSpeed = s[40].value;
          // SENSOR_POWER_WATTS = 73
          if (s[73].supported == 1) powerWatts = s[73].value;
          // SENSOR_GFX_CLK = 1
          if (s[1].supported == 1) gfxClock = s[1].value;
          // SENSOR_MEM_CLK = 2
          if (s[2].supported == 1) memClock = s[2].value;
        }
      } catch (_) {
      } finally {
        calloc.free(out);
      }
    }

    final vramPercent = _dedicatedVramTotalBytes > 0
        ? ((vramUsedBytes / _dedicatedVramTotalBytes) * 100.0).clamp(0.0, 100.0)
        : 0.0;

    return GpuTelemetry(
      name: _gpuName,
      utilPercent: utilPercent,
      dedicatedVramUsedBytes: vramUsedBytes,
      dedicatedVramTotalBytes: _dedicatedVramTotalBytes,
      vramPercent: vramPercent,
      tempEdgeC: tempEdge,
      tempHotspotC: tempHotspot,
      tempMemC: tempMem,
      fanSpeed: fanSpeed,
      powerWatts: powerWatts,
      gfxClockMhz: gfxClock,
      memClockMhz: memClock,
      isAdlAvailable: _adlAvailable,
    );
  }

  void startSampling({int intervalMs = 1500, int? Function()? pidProvider}) {
    stopSampling();
    _pollingTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      final pid = pidProvider?.call();
      final telem = sample(llamaPid: pid);
      if (!_telemetryController.isClosed) {
        _telemetryController.add(telem);
      }
    });
  }

  void stopSampling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  int pidToUint(int pid) => pid & 0xFFFFFFFF;

  void dispose() {
    stopSampling();
    _telemetryController.close();
  }
}
