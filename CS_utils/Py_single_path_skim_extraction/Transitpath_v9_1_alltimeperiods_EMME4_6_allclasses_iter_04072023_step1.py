import inro.emme.desktop.app as _app
import inro.modeller as _m
from zipfile import ZipFile
import os
from datetime import datetime

print("Beginning Analysis")
now = datetime.now()
date_time_str = now.strftime("%Y-%m-%d %H:%M:%S")
print('Start time is:', date_time_str)

my_desktop = _app.connect(port=4242)   # default port 4242 - check under Tools -> Application Options -> Advanced
my_modeller = _m.Modeller(my_desktop)
data_explorer = my_desktop.data_explorer()
database = data_explorer.active_database()

#_m = inro.modeller
NAMESPACE = "inro.emme.transit_assignment.extended.path_details"
#path_details = _m.Modeller().tool(NAMESPACE)
#path_details = my_modeller.tool(NAMESPACE)

spec = {
    "type": "EXTENDED_TRANSIT_PATH_DETAILS",
    "selected_paths": "ALL",
    "details_to_output": {
        "total_impedance": False,
        "total_travel_times": False,
        "times_and_costs": {
            "type": "ACTUAL",
            "first_waiting_time": False,
            "total_waiting_time": True,
            "first_boarding_time": False,
            "total_boarding_time": False,
            "in_vehicle_time": True,
            "aux_transit_time": True,
            "first_boarding_cost": False,
            "total_boarding_cost": True,
            "in_vehicle_cost": False,
            "aux_transit_cost": False
        },
        "avg_boardings": False,
        "distance": True
    },
    "items_for_paths": {
        "zones": True,
        "path_number": False,
        "proportion": False,
        "volume": False,
        "details": True
    },
    "items_for_sub_paths": {
        "nodes": False,
        "mode": True,
        "transit_line": True,
        "aux_transit_sub_paths": True,
        "details": True
    },
    "items_for_od_pairs": {
        "zones": False,
        "number_of_paths": False,
        "demand": False,
        "details": False
    },
    "constraint": {
        "by_zone": {
            "origins": "all",
            "destinations": "all"
        }
    }
}

sc="All"

for scenario in database.scenarios():
    data_explorer.replace_primary_scenario(scenario)
    if "ea" in scenario.title():
        sc="ea"
        Iter = "Iteration 1"
    elif "am" in scenario.title():
        sc = "am"
        Iter = "Iteration 2"
    elif "md" in scenario.title():
        sc = "md"
        Iter = "Iteration 1"
    elif "pm" in scenario.title():
        sc = "pm"
        Iter = "Iteration 2"
    elif "ev" in scenario.title():
        sc = "ev"
        Iter = "Iteration 1"

    if sc != "All":

        path_file = "D:/Insight_Work/AccessTransitPath_EMME_04072023/data/path_details_" + sc + "_WLK_TRN_WLK_Link21_3332_0302_feedback_" + Iter + ".txt"
        my_modeller.tool(NAMESPACE)(specification=spec, output_file=path_file, class_name= Iter + " WLK_TRN_WLK")

        print (sc + " WLK_TRN_WLK done!")
        now = datetime.now()
        date_time_str = now.strftime("%Y-%m-%d %H:%M:%S")
        print('End time is:', date_time_str)

        path_file = "D:/Insight_Work/AccessTransitPath_EMME_04072023/data/path_details_" + sc + "_PNR_TRN_WLK_Link21_3332_0302_feedback_" + Iter + ".txt"
        my_modeller.tool(NAMESPACE)(specification=spec, output_file=path_file, class_name= Iter + ' PNR_TRN_WLK')

        print (sc + "PNR_TRN_WLK done!")
        now = datetime.now()
        date_time_str = now.strftime("%Y-%m-%d %H:%M:%S")
        print('End time is:', date_time_str)

        path_file = "D:/Insight_Work/AccessTransitPath_EMME_04072023/data/path_details_" + sc + "_WLK_TRN_PNR_Link21_3332_0302_feedback_" + Iter + ".txt"
        my_modeller.tool(NAMESPACE)(specification=spec, output_file=path_file, class_name= Iter + ' WLK_TRN_PNR')

        print (sc + "WLK_TRN_PNR done!")
        now = datetime.now()
        date_time_str = now.strftime("%Y-%m-%d %H:%M:%S")
        print('End time is:', date_time_str)

        path_file = "D:/Insight_Work/AccessTransitPath_EMME_04072023/data/path_details_" + sc + "_KNR_TRN_WLK_Link21_3332_0302_feedback_" + Iter + ".txt"
        my_modeller.tool(NAMESPACE)(specification=spec, output_file=path_file, class_name= Iter + ' KNR_TRN_WLK')

        print (sc + "KNR_TRN_WLK done!")
        now = datetime.now()
        date_time_str = now.strftime("%Y-%m-%d %H:%M:%S")
        print('End time is:', date_time_str)

        path_file = "D:/Insight_Work/AccessTransitPath_EMME_04072023/data/path_details_" + sc + "_WLK_TRN_KNR_Link21_3332_0302_feedback_" + Iter + ".txt"
        my_modeller.tool(NAMESPACE)(specification=spec, output_file=path_file, class_name= Iter + ' WLK_TRN_KNR')

        print (sc + "WLK_TRN_KNR done!")
        now = datetime.now()
        date_time_str = now.strftime("%Y-%m-%d %H:%M:%S")
        print('End time is:', date_time_str)

# my_desktop.close()

print ("All finished!")
now = datetime.now()
date_time_str = now.strftime("%Y-%m-%d %H:%M:%S")
print('End time is:', date_time_str)


