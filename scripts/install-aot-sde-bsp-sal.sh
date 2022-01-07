#!/bin/bash

# TODO: define location for SDE -> remove all SCP in this script
# TODO: "ansible"ize

cd ~

sudo apt -y update
sudo apt -y upgrade

scp -o "StrictHostKeyChecking no" netlabadmin@192.168.73.192:/home/netlabadmin/9.7.0_AOT1.6.1_SAL1.3.5_2.zip .
scp -o "StrictHostKeyChecking no" netlabadmin@192.168.73.192:/home/netlabadmin/BF/*.tgz . # e.g., bf-sde-9.7.0.tgz
#scp netlabadmin@192.168.73.192:/home/netlabadmin/bsp/*.tgz . # e.g., bf-reference-bsp-9.7.0.tgz

mkdir BF
mkdir bsp
mv bf-sde-9.7.0.tgz BF
# bsp not needed anymore since 9.7.0 and SAL 1.3.5/AOT 1.6.1?
#mv bf-reference-bsp-9.7.0.tgz bsp

sudo apt -y install unzip

unzip 9.7.0_AOT1.6.1_SAL1.3.5_2.zip

sudo apt -y install python3 python libusb-1.0-0-dev libcurl4-openssl-dev i2c-tools gcc-8 g++-8
sudo apt -y install python3-pip

# need to adapt settings.yaml or provide example
cat << EOF > settings-9.7.yaml
%YAML 1.2
---

# for more information see settings.yaml in AOT directory or https://github.com/APS-Networks/APS-One-touch/blob/master/settings.yaml

PATH_PREFIX: /home/netlabadmin # enforces SDE location, if omitted home dir is using, leading to the SDE not being found when using sudo

BSP:
  aps_bsp_pkg: /bsp/bf-reference-bsp-9.7.0-BF2556_1.0.1 #Porting code for APS switch.

BF SDE:
  sde_pkg: /BF/bf-sde-9.7.0.tgz
  sde_home: /BF/bf-sde-9.7.0 #Path will be automatically created by AOT, this is SDE installation dir path (relative to PATH_PREFIX as every other path in this file). If left blank default is APS-One-touch/<bf-sde-x.y.z>.
  p4studio_build_profile: /BF/bf-sde-9.7.0/p4studio/profiles/p4-runtime-tofino.yaml
  #p4_prog: #Leave it blank to start SDE without a P4 program or give p4 program name which is already built in SDE.
  p4_prog: pronarepeater
  modules: #Following barefoot SDE modules will be loaded before starting SDE.
    - bf_kdrv
    #- bf_kpkt

SAL :
  sal_home: /APS-One-touch-1.6.1/release/sal_1.3.5 #Path to directory where SAL artifacts are present
  tp_install: #3rdParty libs path to run the SAL, defaults to <sal_home>/sal_tp_install
  # If executing SAL tests configure
  dut_ips: #One or more <Switch_IP:SAL_gRPC_port> to execute SAL tests upon,
           #SAL should be running on following device address(es) before running any tests.
    - 127.0.0.1:50054
    - 10.10.192.218:50054
    - 10.10.192.219:50054

EOF

cd APS-One-touch-1.6.1/
# SDE : build y/[n]?y
# Do you want install required dependencies? [Y/n]: Y
# BSP : build y/c(clean)/[n]? y
# SDE : start y/[n]? n
echo -e "y\nY\ny\nn" | python3 bf_sde.py ~/settings-9.7.yaml
# sudo required? ...at least used during python3 bf_sde.py

# during build of BSP?
# CMake Error: The source directory "/home/netlabadmin/bsp/bf-reference-bsp-9.7.0-BF2556_1.0.0" does not exist.
#
# cd /home/netlabadmin/bsp/bf-reference-bsp-9.7.0-BF2556_1.0.1
# cmake .

export SDE=/home/netlabadmin/BF/bf-sde-9.7.0
export SDE_INSTALL=$SDE/install

echo "export SDE=/home/netlabadmin/BF/bf-sde-9.7.0" >>~/.bashrc
echo "export SDE_INSTALL=$SDE/install" >>~/.bashrc

# is there a better way to get SDE/SDE_INSTALL active for user as well as sudo (root)?
echo "export SDE=/home/netlabadmin/BF/bf-sde-9.7.0" | sudo tee -a /root/.bashrc
echo "export SDE_INSTALL=$SDE/install" | sudo tee -a /root/.bashrc

# ugly patch - maybe improve by adding kernel module build to SDE? see also: https://aps-networks.atlassian.net/servicedesk/customer/portal/3/article/1204846593
cd $SDE/pkgsrc/bf-drivers/kdrv/
sed -i '1s;^;cmake_minimum_required(VERSION 3.13)\n;' CMakeLists.txt
cmake . ##You may need to add line like cmake_minimum_required(VERSION 3.13) at the begining od CMakeList.txt##
make ##might throw some errors but check respective kernel directory i.e. ./bf_kdrv/bf_kdrv.ko##
cd bf_kdrv
sudo insmod bf_kdrv.ko
# sudo make install # etc. would be an idea? place kf_kdrv.ko in modules dir etc.? currently breaks, maybe fix build or add kernel modules to build of SDE using 
mkdir -p $SDE_INSTALL/lib/modules/
cp $SDE/pkgsrc/bf-drivers/kdrv/bf_kdrv/bf_kdrv.ko $SDE_INSTALL/lib/modules/

cd ~

# make provided sal binary executable
chmod +x APS-One-touch-1.6.1/release/sal_1.3.5/build/salRefApp

# get libicui18n.so.60 for salRefApp binary
echo "deb http://security.ubuntu.com/ubuntu bionic-security main " | sudo tee /etc/apt/sources.list.d/libicui18n-60-src-for-sal.list
sudo apt-get update
sudo apt-get install libicu60

### APS Switch Dashboard

wget https://raw.githubusercontent.com/prona-p4-learning-platform/aps-switch-dashboard/master/start-switch.sh
chmod +x start-switch.sh
sudo apt install tmux

wget https://github.com/fullstorydev/grpcurl/releases/download/v1.8.5/grpcurl_1.8.5_linux_x86_64.tar.gz
tar zxvf grpcurl_1.8.5_linux_x86_64.tar.gz
./grpcurl -version

# settings: p4_prog: pronarepeater

scp netlabadmin@192.168.73.192:/home/netlabadmin/pronarepeater.p4 .
scp netlabadmin@192.168.73.192:/home/netlabadmin/p4-build-cmake.sh .

./p4-build-cmake.sh pronarepeater
# second run necessary due to configure?
./p4-build-cmake.sh pronarepeater

#2022-01-07 15:52:39.904154 BF_PM ERROR - bf_pm_port_front_panel_port_to_dev_port_get:4245 bf_pm_port_front_pan│2022-01-07 15:52:40.906708 DEBUG BF_PM pm_port_info_get_from_port_hdl:168 pm_port_info_get_from
#el_port_to_dev_port_get: front port 18/0 : not found                                                          │_port_hdl: Unable to get port info: 17/0
#2022-01-07 15:52:39.904232 BF_PM ERROR - bf_pm_port_front_panel_port_to_dev_port_get:4245 bf_pm_port_front_pan│2022-01-07 15:52:40.906772 ERROR BF_PM bf_pm_port_front_panel_port_to_dev_port_get:4245 bf_pm_p
#el_port_to_dev_port_get: front port 33/0 : not found                                                          │ort_front_panel_port_to_dev_port_get: front port 33/0 : not found
#2022-01-07 15:52:39.904309 BF_PM ERROR - bf_pm_port_front_panel_port_to_dev_port_get:4245 bf_pm_port_front_pan│2022-01-07 15:52:39.904283 DEBUG BF_PM pm_port_info_get_from_port_hdl:168 pm_port_info_get_from
#el_port_to_dev_port_get: front port 34/0 : not found                                                          │_port_hdl: Unable to get port info: 34/0
#2022-01-07 15:52:40.906772 BF_PM ERROR - bf_pm_port_front_panel_port_to_dev_port_get:4245 bf_pm_port_front_pan│2022-01-07 15:52:39.904309 ERROR BF_PM bf_pm_port_front_panel_port_to_dev_port_get:4245 bf_pm_p
#el_port_to_dev_port_get: front port 17/0 : not found     

# seams resolved after build BSP again? start SDE using python3 bf_sde.py?

# ./start-switch.sh