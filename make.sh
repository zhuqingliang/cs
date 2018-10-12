#!/bin/bash -x
BUILD_DIR=workspace/reef

KERNEL_REPO=https://github.com/thesofproject/linux.git
SOF_REPO=https://github.com/thesofproject/sof.git
SOFT_REPO=https://github.com/thesofproject/soft.git

KERNEL_BRANCH=topic/sof-dev
SOF_BRANCH=master
SOFT_BRANCH=master

DIR=`pwd`
alias date='date  +"%Y-%m-%d %H:%M:%S"'
FILE_DIR=$(date  +"%Y-%m-%d")
mkdir -p $DIR/$FILE_DIR

update_verity()
{
	BRANCH_NAME=$1
	git remote show origin | grep -A3 "git push" | grep  "[[:blank:]]$1[[:blank:]]"| grep -q 'up to date' 
	return $?
}
linux()
{	
	echo -e "\nmake_kernel" >> $DIR/make.log
	date >> $DIR/make.log
	cd ~/$BUILD_DIR/linux
	git checkout $KERNEL_BRANCH
	update_verity $KERNEL_BRANCH && echo "No kernel $KERNEL_BRANCH update" >> $DIR/make.log && return 0
	git fetch 
	git reset --hard origin/$KERNEL_BRANCH
	local COMMIT_ID=$(git log --pretty=format:"%h" -1)
	echo $COMMIT_ID >> $DIR/make.log
	cp .config .config_bak
	sed -i "s/.*CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"-$COMMIT_ID-noc\"/" .config
	sed -i "s/.*CONFIG_SND_SOC_SOF_FORCE_NOCODEC_MODE.*/CONFIG_SND_SOC_SOF_FORCE_NOCODEC_MODE=y/" .config
	yes| make -j32 deb-pkg

	sed -i "s/.*CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"-$COMMIT_ID\"/" .config
	sed -i "s/.*CONFIG_SND_SOC_SOF_FORCE_NOCODEC_MODE.*/#&/" .config
	echo N | make -j32 deb-pkg

	mv ../linux-image*$COMMIT_ID* $DIR/$FILE_DIR/
}

sof()
{	
#	set -e
	SOF_BRANCH=${1:-master}
	echo -e "\nmake_sof" >> $DIR/make.log
	date >> $DIR/make.log
	cd ~/$BUILD_DIR/sof
	git clean -dxf
	git checkout $SOF_BRANCH
#	update_verity $SOF_BRANCH && echo "No sof $SOF_BRANCH update" >> $DIR/make.log && return 0
	git fetch 
	git reset --hard origin/$SOF_BRANCH
	local COMMIT_ID=$(git log --pretty=format:"%h" -1)
	echo $COMMIT_ID >> $DIR/make.log
	./autogen.sh 
	./configure --enable-rimage
	make &&	sudo make install
	PATH=~/$BUILD_DIR/xtensa-cnl-elf/bin:~/$BUILD_DIR/xtensa-byt-elf/bin:~/$BUILD_DIR/xtensa-sue-elf/bin:~/$BUILD_DIR/xtensa-bxt-elf/bin:~/$BUILD_DIR/xtensa-hsw-elf/bin:~/$BUILD_DIR/xtensa-cnl-elf/bin:$PATH
	echo $PATH
       ./configure --with-arch=xtensa --with-platform=apollolake --with-root-dir=/home/user/workspace/reef/sof/../xtensa-root/xtensa-bxt-elf --host=xtensa-bxt-elf
	make clean
	make && make bin || exit 1 
	./configure --with-arch=xtensa --with-platform=baytrail --with-root-dir=/home/user/workspace/reef/sof/../xtensa-root/xtensa-byt-elf --host=xtensa-byt-elf
	make clean
	make && make bin || exit 1
	#./configure --with-arch=xtensa --with-platform=cannonlake --with-root-dir=/home/user/workspace/reef/sof/../xtensa-root/xtensa-sue-elf --host=xtensa-sue-elf
	./configure --with-arch=xtensa --with-platform=cannonlake --with-root-dir=/home/user/workspace/reef/sof/../xtensa-root/xtensa-cnl-elf --host=xtensa-cnl-elf
	make clean
	make && make bin || exit 1

	#logging
	cp src/arch/xtensa/sof-*.ldc $DIR/$FILE_DIR/

	#gcc
	cp src/arch/xtensa/sof-*.ri $DIR/$FILE_DIR/
	cd $DIR/$FILE_DIR
	for x in sof-*.ri
	do
		mv $x $x-$SOF_BRANCH-gcc-$COMMIT_ID
	done

	#xcc
	cd ~/$BUILD_DIR/sof
	export XTENSA_TOOLS_ROOT=~/xtensa/XtDevTools/
	
	./scripts/xtensa-build-all.sh apl
	cp src/arch/xtensa/sof-*.ri $DIR/$FILE_DIR/
	./scripts/xtensa-build-all.sh cnl
	cp src/arch/xtensa/sof-*.ri $DIR/$FILE_DIR/
	cd $DIR/$FILE_DIR
	for x in sof-*.ri
	do
		mv $x $x-$SOF_BRANCH-xcc-$COMMIT_ID
	done
	
	
}
soft()
{
	echo -e "\nmake soft" >> $DIR/make.log
	date >> $DIR/make.log
	cd ~/$BUILD_DIR/soft
	git clean -df
	git checkout $SOFT_BRANCH
	#update_verity $SOFT_BRANCH && echo "No soft $SOFT_BRANCH update" >> $DIR/make.log && return 0
	git fetch 
	git reset --hard origin/$SOFT_BRANCH
	local COMMIT_ID=$(git log --pretty=format:"%h" -1)	
	echo $COMMIT_ID >>$DIR/make.log
	./autogen.sh 
	./configure
	make 
	make tests

	#logging
	cp logger/sof_logger $DIR/$FILE_DIR
	cp rmbox/logger $DIR/$FILE_DIR

	#tplg
	cp topology/sof-apl-nocodec.tplg $DIR/$FILE_DIR
	cp topology/sof-apl-pcm512x.tplg $DIR/$FILE_DIR
	cp topology/sof-apl-tdf8532.tplg $DIR/$FILE_DIR
	cp topology/sof-byt-nocodec.tplg $DIR/$FILE_DIR
	cp topology/sof-byt-rt5651.tplg $DIR/$FILE_DIR
	cp topology/sof-cnl-rt274.tplg $DIR/$FILE_DIR
	cp topology/test/test-ssp2-mclk-0-I2S-volume-s16le-s16le-48k-19200k-nocodec.tplg $DIR/$FILE_DIR
	cp topology/test/test-ssp2-mclk-0-I2S-volume-s16le-s16le-48k-19200k-codec.tplg $DIR/$FILE_DIR
	cp topology/test/test-ssp2-mclk-0-I2S-volume-s24le-s24le-48k-19200k-codec.tplg $DIR/$FILE_DIR
	cd $DIR/$FILE_DIR
	for x in *.tplg
	do
		mv $x $x-$COMMIT_ID
	done
}
#linux
sof
sof stable-1.2
soft
