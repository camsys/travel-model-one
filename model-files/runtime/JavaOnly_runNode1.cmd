cd ..
cd ..
mkdir logs

rem ############  PARAMETERS  ############
:: Set the path
call CTRAMP\runtime\SetPath.bat

set HOST_IP=10.13.1.135

rem ############  JPPF DRIVER  ############
start "Node 1" java -server -Xmx128m -Dlog4j.configuration=log4j-node1.xml -Djppf.config=jppf-node1.properties org.jppf.node.NodeLauncher
