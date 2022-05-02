git clone https://github.com/MJoergen/C64MEGA65.git

cd C64MEGA65

(checkout develop)

git submodule update --init --recursive

Print and check correct hashes in the doc, so that people can double-check:
Submodule path 'C64_MiSTerMEGA65': checked out 'a455c46cb9e4e09eb7807b88ee57549553138504'
Submodule path 'QNICE': checked out 'de7898d1491ce81795971e92c3b0f7edd1f6d2c4'

cd QNICE/tools/

./make_toolchain.sh
(answer all questions with ENTER)

cd ../../CORE/m2m-rom/

./make_rom.sh 

qasm2rom: 12488 ROM lines written.
(print the lines for people to double-check)

