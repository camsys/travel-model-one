cd ..
cd ..
mkdir logs

rem ############  PARAMETERS  ############
:: Set the path
call CTRAMP\runtime\SetPath.bat

set HOST_IP=10.13.1.135

rem ############  JPPF DRIVER  ############
start "Node 4" java -server -Xmx128m -Dlog4j.configuration=log4j-node4.xml -Djppf.config=jppf-node4.properties org.jppf.node.NodeLauncher
