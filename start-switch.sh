#!/bin/bash

### Override SDE vars

#SDE=/home/netlabadmin/BF/bf-sde-9.4.0
#SDE_INSTALL=$SDE/install

### BEGIN CONFIG

#APS_ONE_TOUCH_VER=APS-One-touch-1.4.2
#SAL_VER=sal_1.2.0
APS_ONE_TOUCH_VER=APS-One-touch-1.6.1
SAL_VER=sal_1.3.5
#APS_ONE_TOUCH_SETTINGS=""
APS_ONE_TOUCH_SETTINGS_FILE="/home/netlabadmin/settings-9.7.yaml"
GRPC_PORT=50054

### END CONFIG



APS_ONE_TOUCH_REL=/home/netlabadmin/$APS_ONE_TOUCH_VER
SAL_REL=$APS_ONE_TOUCH_VER/release/$SAL_VER



### init switch network interfaces e.g. for CPU port comm etc. using kpkt, kdrv:
#/home/netlabadmin/prepare-kpkt.sh

### compile p4 prog and configure sal etc.


# maybe offer option to attach if session already exists?
sudo tmux kill-session -t asd

sudo tmux new-session -d -s asd

sudo tmux split-window -v -p 70 -t asd
sudo tmux split-window -v -p 50 -t asd
sudo tmux split-window -h -p 40 -t asd.0



### Window 0: Run sal.py, starting sal, SDE etc., waits for gRPC SAL server to become available

# explicitly set SDE (e.g., since using sudo)
# TODO: ingnore in this case, since sudo is using env of root?
sudo tmux send-keys -t asd.0 "export SDE=$SDE" Enter
sudo tmux send-keys -t asd.0 "export SDE_INSTALL=$SDE_INSTALL" Enter

sudo tmux send-keys -t asd.0 "cd $APS_ONE_TOUCH_REL && echo 'r' | sudo python3 sal.py $APS_ONE_TOUCH_SETTINGS_FILE" Enter

echo "Waiting for gRPC server on port port $GRPC_PORT..."
while ! nc -z localhost $GRPC_PORT; do
  sleep 0.1
done



###### Window 1: Show log of running SAL, SDE, BSP

sudo tmux send-keys -t asd.1 "cd $APS_ONE_TOUCH_REL && tail -f *.log" Enter



###### Window 2: Send gRPC calls to SAL to start tofino and marvell gearbox

# explicitly set SDE (e.g., since using sudo)
sudo tmux send-keys -t asd.2 "export SDE=$SDE" Enter
sudo tmux send-keys -t asd.2 "export SDE_INSTALL=$SDE_INSTALL" Enter

sudo tmux send-keys -t asd.2 "./grpcurl -proto $SAL_REL/proto/sal_services.proto -plaintext localhost:50054 sal_services.SwitchService.TestConnection" Enter
sudo tmux send-keys -t asd.2 "./grpcurl -proto $SAL_REL/proto/sal_services.proto -plaintext localhost:50054 sal_services.SwitchService.GetSwitchModel" Enter
sudo tmux send-keys -t asd.2 "./grpcurl -proto $SAL_REL/proto/sal_services.proto -plaintext localhost:50054 sal_services.SwitchService.StartTofino" Enter
sudo tmux send-keys -t asd.2 "./grpcurl -proto $SAL_REL/proto/sal_services.proto -plaintext localhost:50054 sal_services.SwitchService.StartGearBox" Enter

### add and init ports through sal, only necessary for own p4 pgorams like pronarepeater, switch.p4 etc. will add ports themselves
sudo tmux send-keys -t asd.2 "./grpcurl -d '{ \"portId\": { \"portNum\": 17, \"lane\": 0 }, \"portConf\": { \"speed\": 6, \"fec\": 3, \"an\": 2, \"enable\": 1 } }' -proto $SAL_REL/release/sal/proto/sal_services.proto -plaintext localhost:50054 sal_services.SwitchService.AddPort" Enter
sudo tmux send-keys -t asd.2 "./grpcurl -d '{ \"portId\": { \"portNum\": 18, \"lane\": 0 }, \"portConf\": { \"speed\": 6, \"fec\": 3, \"an\": 2, \"enable\": 1 } }' -proto $SAL_REL/release/sal/proto/sal_services.proto -plaintext localhost:50054 sal_services.SwitchService.AddPort" Enter

### get config from sal
#sudo tmux send-keys -t asd.2 "./grpcurl -d '{ \"portNum\": 16, \"lane\": 0}' -proto APS-One-touch-1.4.1/release/sal/proto/sal_services.proto -plaintext localhost:50054 sal_services.SwitchService.GetPortConfig" Enter
#sudo tmux send-keys -t asd.2 "./grpcurl -d '{ \"portNum\": 17, \"lane\": 0}' -proto APS-One-touch-1.4.1/release/sal/proto/sal_services.proto -plaintext localhost:50054 sal_services.SwitchService.GetPortConfig" Enter
#sudo tmux send-keys -t asd.2 "./grpcurl -d '{ \"portNum\": 16, \"lane\": 0}' -proto APS-One-touch-1.4.1/release/sal/proto/sal_services.proto -plaintext localhost:50054 sal_services.SwitchService.GetSFPCInfo" Enter
#sudo tmux send-keys -t asd.2 "./grpcurl -d '{ \"portNum\": 17, \"lane\": 0}' -proto APS-One-touch-1.4.1/release/sal/proto/sal_services.proto -plaintext localhost:50054 sal_services.SwitchService.GetSFPCInfo" Enter



###### Window 3: Open bfshell

# explicitly set SDE (e.g., since using sudo)
sudo tmux send-keys -t asd.3 "export SDE=$SDE" Enter
sudo tmux send-keys -t asd.3 "export SDE_INSTALL=$SDE_INSTALL" Enter
### example for switch.p4:
#sudo tmux send-keys -t asd.3 "$SDE/run_bfshell.sh -f bf_config_switch.txt && cd $SDE && ./run_bfshell.sh" Enter
### example for pronarepeater:
sudo tmux send-keys -t asd.3 "cd $SDE && ./run_bfshell.sh" Enter

sudo tmux select-pane -t asd.3

sudo tmux attach -t asd
