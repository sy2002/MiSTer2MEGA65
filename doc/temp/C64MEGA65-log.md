# Porting guidelines

This document will eventually morph into a generic HowTo guide.  However,
initially it will record my efforts and experiences porting the
[https://github.com/MiSTer-devel/C64_MiSTer](C64_MiSTer).

## 1. Project setup
Since the porting process will most likely require small local modifications 
to the MiSTer core, it is necessary to make a **fork** of the MiSTer core.
The first step is therefore to setup the projects.

### 1.1. Forking the MiSTer core:
1. Navigate to the `C64_MiSTer` [core](https://github.com/MiSTer-devel/C64_MiSTer) and press the "Fork" button.
2. Press "Settings" and rename the core to `C64_MiSTerMEGA65`.

### 1.2. Forking the MiSTer2MEGA65 repository.
1. Navigate to the `MiSTer2MEGA65` [repo](https://github.com/sy2002/MiSTer2MEGA65) and press the "Fork" button.
2. Press "Settings" and rename the core to `C64MEGA65`.

### 1.3. Cloning the repositories
The idea in the following is to add the `C64_MiSTerMEGA65` as a git submodule
to the `C64MEGA65`. Additionally, in order to easily keep the two repositories
up-to-date with the original, we add an upstream pointer to the original.
Finally, we create a new branch called `m2m` to use for all our local
changes. Keeping these changes on a separate branch makes it easier to
merge in upstream changes from the original repos.

```
git clone https://github.com/MJoergen/C64MEGA65.git
cd C64MEGA65
git submodule update --init --recursive
git remote add upstream https://github.com/sy2002/MiSTer2MEGA65.git
git checkout -b m2m

git submodule add git@github.com:MJoergen/C64_MiSTerMEGA65.git
cd C64_MiSTerMEGA65
git submodule update --init --recursive
git remote add upstream https://github.com/MiSTer-devel/C64_MiSTer.git
git checkout -b m2m
cd ..
```

There is [more information on git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules).

### 1.4. Prepare the QNICE subrepo

```
cd QNICE/tools
./make_toolchain.sh
cd ../..
```

### 1.5. Rename project files
You can (TBD: should?) choose a name for the Vivado project different from the
default name:

```
cd MEGA65
mv MEGA65-R3.xdc C64MEGA65-R3.xdc
mv MEGA65-R3.xpr C64MEGA65-R3.xpr
cd ..
```

## 2. Add the MiSTer core
Now that the project is setup, we're ready to add the MiSTer core to the M2M framework

### Open Vivado and add files to the project
* Select "Add Sources" -> "Add Directories" and navigate to `C64_MiSTerMEGA65/rtl`
* Make sure "Copy sources into project" is NOT selected.
* Make sure "Add sources from subdirectories" IS selected.
* Click "Finish"

### Connecting the MiSTer core
The MiSTer core is instantiated in the file MEGA65/vhdl/main.vhd

## 3. Fixing errors during elaboration
At this stage, the core is now properly added to the project. However, the work
is still far from over. It seems the Vivado tool for Xilinx FPGA's is less
forgiving than the Quartus tool for Intel FPGA's. So a number of minor edits
are needed in the source files of the core in order for Vivado to work with
them. This is where it is convenient to have made a separate branch of a
private fork of the MiSTer core.

To get a report of the errors to be fixed click the `Open Elaboration` option.
This will show the error. Unfortunately, only one error is shown each time. So
the process is to fix this single error, and then to repeat the process until
no more elaboration errors are shown.

### 3.1. `[Synth 8-2576] procedural assignment to a non-register <name> is not permitted`
This error is caused by not declaring a register using the `reg` keyword. Even
a purely combinatorial signal will be treated as a register, if it is assigned
to within an `always_comb` block.  The fix is to add the `reg` keyword to the
declaration of the register mentioned in the error.

### 3.2. `[Synth 8-1873] declarations not allowed in unnamed block`
This error occurs when declaring local signal within an `always` block.
Apparently this is not allowed. However, the fix is very easy. Just add a label
after the `begin` keyword.

### 3.3. `[Synth 8-2671] single value range is not allowed in this mode of verilog`
This error is because Vivado tries to auto-detect whether a source file a pure
verilog or SystemVerilog based on the file extension (`.v` versus `.sv`). In
this case a file was erroneously classified a pure verilog. The fix is to
locate the file in the `Sources` tab and then in the `Source File Properties`
tab to change the `Type` from `Verilog` to `SystemVerilog`.

