# Porting guidelines

This document will eventually morph into a generic HowTo guide.  However,
initially it will record my efforts and experiences porting the
[https://github.com/MiSTer-devel/C64_MiSTer](C64_MiSTer).

## Project setup
Since the porting process will most likely require small local modifications 
to the MiSTer core, it is necessary to make a **fork** of the MiSTer core.

### Forking the MiSTer core:
1. Navigate to the `C64_MiSTer` [core](https://github.com/MiSTer-devel/C64_MiSTer) and press the "Fork" button.
2. Press "Settings" and rename the core to `C64_MiSTerMEGA65`.

### Forking the MiSTer2MEGA65 repository.
1. Navigate to the `MiSTer2MEGA65` [repo](https://github.com/sy2002/MiSTer2MEGA65) and press the "Fork" button.
2. Press "Settings" and rename the core to `C64MEGA65`.

### Cloning the repositories
The idea in the following is to add the `C64_MiSTerMEGA65` as a git submodule
to the `C64MEGA65`. Additionally, in order to easily keep the two repositories
up-to-date with the original, we add an upstream pointer to the original.

```
git clone git@github.com:MJoergen/C64MEGA65.git
cd C64MEGA65
git remote add upstream git@github.com:sy2002/MiSTer2MEGA65.git

git submodule add git@github.com:MJoergen/C64_MiSTerMEGA65.git
cd C64_MiSTerMEGA65
git remote add upstream https://github.com/MiSTer-devel/C64_MiSTer.git
cd ..
```

There is [more information on git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules).

### Prepare the QNICE subrepo

```
cd QNICE/tools
./make_toolchain.sh
cd ../..
```

### Rename project files
```
cd MEGA65
mv MEGA65-R3.xdc C64MEGA65-R3.xdc
mv MEGA65-R3.xpr C64MEGA65-R3.xpr
cd ..
```

### Open Vivado and add files to the project
* Select "Add Sources" -> "Add Directories" and navigate to `C64_MiSTerMEGA65/rtl`
* Make sure "Copy sources into project" is NOT selected.
* Make sure "Add sources from subdirectories" IS selected.
* Click "Finish"

