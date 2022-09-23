cd ..
cd ..
mkdir logs

rem ############  PARAMETERS  ############
:: Set the path
call CTRAMP\runtime\SetPath.bat

set HOST_IP=10.0.143.35

rem ############  JPPF DRIVER  ############
start "Node 0" java -server -Xmx128000m -Dlog4j.configuration=log4j-node0.xml -Djppf.config=jppf-node0.properties org.jppf.node.NodeLauncher
