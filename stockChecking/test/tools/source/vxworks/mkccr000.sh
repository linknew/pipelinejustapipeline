#! /bin/bash

basedir="sourceChecking/review-000-files/"

#files='helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/debugsocket/src/debugSocketDev.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/include/binParse.h
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/include/configLib.h
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/include/errno.h
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/include/hvFrameSched.h
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/include/hvHm.h
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/include/libraries/libfdt/fdt.h
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/include/strings.h
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/include/sys/arch.h
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/include/sys/devices/drivers/gpuMgrStart.h
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/include/sys/hvEvtLogLibP.h
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/include/sys/regs.h
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/include/sys/sysinfo.h
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/include/sys/types.h
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/include/sys/vmmu.h
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/include/sys/wrhvConfig.h
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/include/sys/wrhvDss.h
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/include/usr/usrStartup.h
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/include/vmArch.h
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/include/vmDynamic.h
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/dllLib.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/ivtreeLib.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/qFifoLib.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/rbtreeLib.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/sllLib.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/timeEventLib.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/version.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/wrhv.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/wrhvClkLib.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/wrhvCoreTimeout.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/wrhvDss.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/wrhvEmulatedDevice.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/wrhvEmulatedDeviceMap.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/wrhvEvent.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/wrhvHm.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/wrhvHvTestHarness.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/wrhvInterrupt.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/wrhvMemMgr.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/wrhvMmu.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/wrhvMsg.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/wrhvTimeout.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/wrhvTimer.c
#helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/kernel/src/xcall.c'


files='helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/absvdi2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/absvsi2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/absvti2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/addtf3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/addvdi3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/addvsi3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/addvti3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/ashldi3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/ashlti3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/ashrdi3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/ashrti3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/atomic_flag_clear.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/atomic_flag_clear_explicit.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/atomic_flag_test_and_set.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/atomic_flag_test_and_set_explicit.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/atomic_signal_fence.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/atomic_thread_fence.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/clzdi2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/clzsi2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/clzti2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/cmpdi2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/cmpti2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/comparedf2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/comparesf2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/comparetf2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/ctzdi2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/ctzsi2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/ctzti2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/divdi3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/divmoddi4.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/divmodsi4.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/divsi3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/divtf3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/divti3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/extenddftf2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/extendsftf2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/ffsdi2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/ffsti2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixdfdi.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixdfsi.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixdfti.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixsfdi.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixsfsi.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixsfti.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixtfdi.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixtfsi.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixtfti.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixunsdfdi.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixunsdfsi.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixunsdfti.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixunssfdi.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixunssfsi.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixunssfti.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixunstfdi.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixunstfsi.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixunstfti.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixunsxfdi.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixunsxfsi.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixunsxfti.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixxfdi.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fixxfti.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/floatditf.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/floatdixf.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/floatsitf.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/floattixf.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/floatunditf.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/floatundixf.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/floatunsitf.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/floatuntixf.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fp_add_impl.inc
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fp_extend_impl.inc
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fp_fixint_impl.inc
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fp_fixuint_impl.inc
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fp_lib.h
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fp_mul_impl.inc
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/fp_trunc_impl.inc
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/int_lib.h
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/int_math.h
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/int_util.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/int_util.h
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/lshrdi3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/lshrti3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/moddi3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/modsi3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/modti3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/muldi3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/mulodi4.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/mulosi4.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/muloti4.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/multc3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/multf3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/multi3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/mulvdi3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/mulvsi3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/mulvti3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/mulxc3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/negdi2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/negti2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/negvdi2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/negvsi2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/negvti2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/paritydi2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/paritysi2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/parityti2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/popcountdi2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/popcountsi2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/popcountti2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/powitf2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/powixf2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/subtf3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/subvdi3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/subvsi3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/subvti3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/trampoline_setup.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/truncdfhf2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/truncsfhf2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/trunctfdf2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/trunctfsf2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/ucmpdi2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/ucmpti2.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/udivdi3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/udivmoddi4.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/udivmodsi4.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/udivmodti4.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/udivsi3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/udivti3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/umoddi3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/umodsi3.c
helix/guests/vxworks-7/pkgs_v2/os/hv/hypervisor/vmm/libraries/librt/umodti3.c'



git pull -p
[[ ! -d "$basedir" ]] && mkdir -p "$basedir"
rm -rf $basedir/*
tar -cvf - $files | tar -xvf - -C"$basedir"


