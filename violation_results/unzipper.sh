#!/bin/bash
# Given a tar.gz archive, unzip it to scratch/
# We should pick out only which violations we need to manual run on gem5zor test analyzer!

ARCHIVE=STT-Spectre-ST-ARCHSEQ.tar.gz

echo "Unzipping archive $ARCHIVE";
mv -v scratch _zombie;
rm -rf _zombie &

mkdir scratch;
tar -xzvf $ARCHIVE -C scratch;
echo "Done unzipping archive $ARCHIVE";