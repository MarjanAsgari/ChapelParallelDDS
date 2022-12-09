
use List;
use Sort;
use Random.PCGRandom;
use IO;
use FileSystem;
use Spawn;
use runIMWEBs;
use ParameterSet;
use Records;
//use IMWEBsCalibrationProgram;

/* I am wrapping all the methods in this module in a class, which gives me the option to call this class initializer and set some important variables that are used by most of the methods in this module */
class ProgramDatabase{

    var EFProjectPath:string;
    var MeasureDBPath: string;
    var hostname: string;
    var StoppingMDR: real;
    var hostID: real;
    var ProjectName:string;
    var ListName:string;
    var Parallelization_Strategy: string;
    var Calibration_Type: string;
    var Calibration_Algorithm_Name: string;
    var DoInfoExchange:string;
    var Stopping_Criteria:string;
    var Exchange_Frequency:real;
    var Number_FArchives_Exchange:real;
    var Stopping_Value:real;
    var Num_Allowed_In_Archive:real;
    var Bound_Archive:string;
    var LastSimID: string;
    var BestF: real; 
    var SimulationIDU: string;
    var Dominance: string;
    var TotalF: list(string);
    var LocalFValue: bool;
    var LocalPerformanceString: string;
    var MeasureScope: string;
    var curentParsetID: string;
    var SRCCFrequency: real; 
    var BestParArchive: list(shared Parameter, parSafe=true);
    var ParsetList: list (EpsilonParset);
    var ArchivesList: list(EpsilonArchive);
    var MultiObjType: string;
    var FlowAverage: string;
    var StopAlgorithm: int;
    var MasterBestParsets: list(list(shared Parameter, parSafe=true));
    var MasterBestParsetsSingle: list(shared Parameter, parSafe=true);


    proc init(ProjectPath:string, Projectname:string) {

        this.EFProjectPath = ProjectPath;
        this.hostname = here.hostname;
        this.hostID = here.id;
        this.ProjectName = Projectname;

    }
    proc init(ProjectPath:string, Projectname:string, hostname:string, hostid: real) {

        this.EFProjectPath = ProjectPath;
        this.hostname = hostname;
        this.hostID = hostid;
        this.ProjectName = Projectname;
    }

    /* This function is for Creating the EF core database on each worker Node. 
        This Function only once, at the beginning of the program on the worker node, will be called on each worker. */
    proc ProgramDBCreation(){
        var MigrationName = "".join("EF", hostname);
        var AddMig_Command = " ".join("dotnet ef Migrations add --context Main_PhD_Project_Database", MigrationName, "--project", EFProjectPath);
        var Mig = spawnshell(AddMig_Command, stdout=PIPE);
        var line: string;
        while Mig.stdout.readline(line) {
            if (line.find("Build succeeded.") != -1){
                break;
            } else {
                writeln("Error: Program Database Migration Failed!");
            }
        }
        Mig.wait();
        var upd_Command = " ".join("dotnet ef database update --context Main_PhD_Project_Database", MigrationName, "--project", EFProjectPath);
        var upd = spawnshell(upd_Command,stdout=PIPE);
        while upd.stdout.readline(line) {
            if (line.find("Build succeeded.") != -1){
                break;
            } else {
                writeln("Error: Program Database Update Failed!");
            }
        }
        upd.wait();
    }

                                        /* ----------------------------Updating Tables Functions-------------------- */

    /*
    Usage: For the Functional Strategy, this table should be filled at the beginning of the Program on the Master Node, to get the general info about the Machines we have on our cluster 
    Input: It should have data for all the columns we have for teh ComputersInfo table 
    Output: NOn --> Updates table 
    Where this Function is used: At the beginning of the program 
    C# functions: It works with "updateComputerTbl" Function
    --NOTE-- You might need to EXPAND it for the Dependent Multi-search
    */

    /*---------------------------------------------------------------CHECKED-------------------------------------------------------------*/
    proc ComputersInfoUpdate(StartSim: list(string), TotalNumSim: list(int), Architecture:string, ParStrategy:string, HostID: list(int), hostname: list(string), slmpath:string){

        var SimStartID = StartSim;
        var Com_update = "dotnet run UpdateComputerInfo";
        if (ParStrategy == "Functional"){
            var n = HostID.size - 1; 
            var Com_Update_input: string;
            for i in 0..n {
                if (HostID[i] == 0){
                    Com_Update_input = " ".join(Com_update, hostname[i], SimStartID[i]:string, TotalNumSim[i]:string, "Master", Architecture, ProjectName, EFProjectPath, slmpath, "--project", EFProjectPath);
                }
                else {
                    Com_Update_input = " ".join(Com_update, hostname[i], SimStartID[i]:string, TotalNumSim[i]:string, "Worker", Architecture, ProjectName, EFProjectPath, slmpath, "--project", EFProjectPath);
                }
                var Com_Update = spawnshell(Com_Update_input, stdout=PIPE);
                var line: string;
                while Com_Update.stdout.readline(line){
                    if (line.isEmpty() == true){
                        writeln(line);
                    } else{
                        writeln("Error: Updating Computer_Info Table Failed!");
                        writeln(Com_Update_input);
                    }
                }
                Com_Update.wait();
            }
        }
    }
        /*---------------------------------------------------------------CHECKED-------------------------------------------------------------*/
    proc ComputersInfoUpdateTemp(StartSim: string, TotalNumSim: int, Architecture:string, ParStrategy:string, HostID: int, hostname: string){

        var SimStartID = StartSim;
        var Com_update = "dotnet run UpdateComputerInfo";
        var Com_Update_input = " ".join(Com_update, hostname, SimStartID, TotalNumSim:string, "Master", Architecture, ProjectName, EFProjectPath, "--project", EFProjectPath);
        var Com_Update = spawnshell(Com_Update_input);
        Com_Update.wait();
    }
    /*
    Usage: For the Functional Strategy, this table should be filled at the beginning of the Program on the Master Node, after the Computers info to get info about each computer 
    Input: It should have the host name of the computer and the number of cores we have for each computer 
    Output: NOn --> Updates table 
    Where this Function is used: At the beginning of the program 
    C# functions: It works with "updateCPUTbl" Function, */

    /*---------------------------------------------------------------CHECKED-------------------------------------------------------------*/
    proc CPUInfoUpdate(hostname:string, numcores: real, slrmPath:string){

        var CPU_update = "dotnet run UpdateCPUInfo";
        var numcoresI = numcores: int;
        var CPU_Update_input = " ".join(CPU_update, hostname, numcoresI:string, slrmPath,"--project", EFProjectPath);
        var CPU_Update = spawnshell(CPU_Update_input, stdout=PIPE);
        var line: string;
        while CPU_Update.stdout.readline(line){
            if (line.isEmpty() == true){
                writeln(line);
            } else {
                writeln("Error: Updating CPU_Info Table Failed!om Machine %s", here.hostname);
                writeln(CPU_Update_input);
            }
        }
        CPU_Update.wait();
    }
    /*
    Usage: This Function adds to the Simulation_General_Info table. 
    Input: We should know the Simulation ID, ParameterSet ID, start time of the IMWEBs model, Endtime of the IMWEBs model and the total Run of the IMWEBs model to fill the table
    Output: NON --> Updates table 
    Where this Function is used: At each single Simulation --> For the Functional Strategy it runs on the Master Node only 
    C# functions: It works with "InsertSimGeneralInfo" Function. 
    --Note -->  Before Updating this table, you need to make sure that the Base_Project table is updated and it is there*/

    
    proc Simulation_General_Info_update(SimID: string, ParsetID:string, startTD:string, endTD:string, totalrun:real){

        var Simgen_Insert_command = "dotnet run UpdateSimGeneralInfo";
        var Simgen_Insert_input = " ".join(Simgen_Insert_command, SimID:string, ParsetID, hostname, ProjectName, startTD, endTD, totalrun:string, "--project", EFProjectPath);
        var Simgen_Insert = spawnshell(Simgen_Insert_input, stdout=PIPE);
        var line: string;
        while Simgen_Insert.stdout.readline(line) {
            if (line.isEmpty() == true){
                break;
            } else {
                writeln("Error: Updating Simulation_General_Info Table Failed!");
            }
        }
        Simgen_Insert.wait();
    }
    /*
    Usage: This Function adds to the ParameterSet table. 
    Input: We only need to have the ParameterSet and teh ParameterSet ID to do so. 
    Output: NON --> Updates table 
    Where this Function is used: At each single Simulation --> For the Functional Strategy it runs on the Master Node only 
    C# functions: It works with "InsertSimGeneralInfo" Function. 
    --Note -->  Before updating it, the  Simulation_General_Info table should get updated*/
    proc ParameterSet_Table_Update(parameters: list(shared Parameter, parSafe=true), ParSetID: string){

        for i in parameters do {
            var Parset_Insert_command = "dotnet run UpdateParameterSet";
            var Parset_Insert_input = " ".join(Parset_Insert_command, ParSetID, i.getParametercalID():string, i.getCurrentValue():string, "--project", EFProjectPath);
            var SimIDSELECT = spawnshell(Parset_Insert_input, stdout=PIPE);
            var line: string;
            while SimIDSELECT.stdout.readline(line) {
                if (line.isEmpty() == true){
                    break;
                } else {
                writeln("Error: Updating Simulation_General_Info Table Failed!");
                }
            }
            SimIDSELECT.wait();
        }
    }
    /*
    Usage: This Function adds to the Simulation Summary table. 
    Input: We only need to have the ParameterSet and teh ParameterSet ID to do so. 
    Output: NON --> Updates table 
    Where this Function is used: At each single Simulation --> For the Functional Strategy it runs on the Master Node only 
    C# functions: It works with "getSummaryTypesbyTableNames" which looks at the ProjectNeededSummaries table and by using the ProjectName, it figures out which summaries we need to have.
    Then by using the "SummaryTableUpdate" function and the result of the previous function, it updates the Simulation Summary table 
    --Note -->  Before Updating this table, you need to make sure that the Simulation_General_Info_update table is updated */


    proc Simulation_Summary_Update(SimID: string, path:string){

        var SimSummary_Insert_command = "dotnet run UpdateSummaryTable";
        var SimSummary_Insert_input = " ".join(SimSummary_Insert_command, ProjectName, SimID:string, "--project", EFProjectPath, path);
        var SimSummary = spawnshell(SimSummary_Insert_input, stdout=PIPE);
        var line: string;
        while SimSummary.stdout.readline(line) {
            if (line.isEmpty() == true){
                break;
            } else {
                writeln("Error: Updating Simulation_Summary Table for Defined Tables Failed!");
            }
        }
        SimSummary.wait();
    }
    /*
    Usage: This Function adds to the Simulation Performance table. 
    Input: We need a value for each single column we have in the Performance Table 
    Output: NON --> Updates table 
    Where this Function is used: The point is in a functional parallelization strategy, 
    we send the simulation performance Info as a list of strings to the Master Tabel and Master Table should read each row and add it to the Simulation Performance Table. 
    So this function is ONLY FOR THE FUNCTIONAL STRATEGY AND FOR TEH MASTER NODE.
    C# functions: NO Function */
    proc SimulationPerformanceReadandWrite(simID:string, ParSetID:string, varname:string, IndicName:string, Indicvalue:string, WIndicvalue:string){

        var SimPer_Insert_command = "dotnet run UpdateIndicatorsTableFunctional";
        var SimPer_Insert_input = " ".join(SimPer_Insert_command, simID, ParSetID, varname, IndicName, WIndicvalue, Indicvalue, "--project", EFProjectPath);
        var SimPerformance = spawnshell(SimPer_Insert_input, stdout=PIPE);
        var line: string;
        while SimPerformance.stdout.readline(line) {
            if (line.isEmpty() == true){
                break;
            } else {
                writeln("Error: Updating Simulation_Performance_Info Table Failed!");
            }
        }
        SimPerformance.wait();
    }
    /*
    Usage: This Function adds to the Simulation Performance table // This is For Multi-Search Strategy where we update the table by using information 
    from other tables and not by getting info from the program 
    Input: We just need a hostname and Projectname 
    Output: NON --> Updates table 
    Where this Function is used: At each simulation.
    C# functions: updateIndicatorsTable Funcation which is a big and Complicated function with working with a wide range of Tables -->
    MeasurementID_Lookup_Seed / IMWEBs_Output_Fields_Seed / Performance_Indicators_Seed
        Model_Variable_Seed / and Measurement and Simulation DBs*/
    proc Simulation_Performance_Info_Update(){

        var SimPer_Insert_command = "dotnet run UpdateIndicatorsTable";
        var SimPer_Insert_input = " ".join(SimPer_Insert_command, ProjectName, "true", hostname, hostID:string, "--project", EFProjectPath);
        var SimPerformance = spawnshell(SimPer_Insert_input, stdout=PIPE);
        var line: string;
        while SimPerformance.stdout.readline(line) {
            if (line.isEmpty() == true){
                break;
            } else {
                writeln("Error: Updating Simulation_Performance_Info Table Failed!");
            }
        }
        SimPerformance.wait();
    }
    /*---------------------------------------------------------------CHECKED-------------------------------------------------------------*/
    proc getSingleObjectiveValue(Performance: list(list(string)), ObjectiveName: string, VarName: string){
        
        var returnValue: real; 
        if (ObjectiveName.startsWith("TotalF") == false){
            for Per in Performance{
                if (Per[0] == VarName){
                    if (Per[3].startsWith("KGE") == true && ObjectiveName.startsWith("KGE") == true) {
                        returnValue = 1-(Per[5]:real);
                    }
                    if (Per[3].startsWith("PBIAS") == true && ObjectiveName.startsWith("PBIAS") == true) {
                        returnValue = abs(Per[5]:real);
                    }
                }
            }
        } else if (ObjectiveName.startsWith("TotalF") == true){
            var SumObjValues: real;
            var KGEWeight: real = 0.0;
            var PBIASWeight: real = 0.0;
            for Per in Performance {
                if (Per[0] == VarName){
                    if (Per[3].startsWith("KGE") == true) {
                        if (1-(Per[5]):real > 0.5) {
                           if (KGEWeight == 0) {
                                KGEWeight = 0.7;
                                PBIASWeight = 0.3;
                            } 
                            else {
                                KGEWeight =  0.5;
                                PBIASWeight = 0.5;
                            }
                        } 
                    } 
                    if (Per[3].startsWith("PBIAS") == true) {
                        if (abs(Per[5]:real) > 0.6) {
                            if (KGEWeight == 0) {
                                KGEWeight =  0.3;
                                PBIASWeight = 0.7;
                            } else {
                                KGEWeight =  0.5;
                                PBIASWeight = 0.5;
                            }
                        }
                    }
                }
            }
            if (KGEWeight == 0.0  && PBIASWeight == 0.0) {
                for Per in Performance {
                    if (Per[0] == VarName){
                        if (Per[3].startsWith("KGE") == true){
                            SumObjValues = SumObjValues + (1-(Per[5]:real))*0.5;
                        }
                        if (Per[3].startsWith("PBIAS") == true) { 
                            SumObjValues = SumObjValues + abs(Per[5]:real)*0.5;
                        }
                    }
                }
            } else {
                for Per in Performance {
                    if (Per[0] == VarName){
                        if (Per[3].startsWith("KGE") == true){
                            SumObjValues = SumObjValues + (1-(Per[5]:real))*KGEWeight;
                        }
                        if (Per[3].startsWith("PBIAS") == true) { 
                            SumObjValues = SumObjValues + abs(Per[5]:real)*PBIASWeight;
                        }
                    }
                }
            }
            returnValue = SumObjValues;
        }
        return returnValue;  
    }

    proc getObjectiveFValues(Performance: list(list(string)), VarName: string){
        
        var returnValue: list(string);
        for Per in Performance {
            if (Per[0] == VarName){
                if (Per[3].startsWith("KGE") == true){
                    returnValue.append("KGE");
                    returnValue.append((1-(Per[5]:real)):string);
                }
                if (Per[3].startsWith("PBIAS") == true) { 
                    returnValue.append("PBIAS");
                    returnValue.append(Per[5]);
                }
            }
        }
        return returnValue;  
    }
    proc getObjectiveFValuesMulti(Performance: list(list(string))){
        var returnValue: list(string);
        for Per in Performance {
            if (Per[3].startsWith("KGE") == true){
                returnValue.append("KGE");
                returnValue.append((1-(Per[5]:real)):string);
            }
            if (Per[3].startsWith("PBIAS") == true) { 
                returnValue.append(Per[0]);
                returnValue.append("PBIAS");
                returnValue.append(Per[5]);
            }
        }
        return returnValue;  
    }
    /*
    Usage: This Function adds to the Simulation Performance table // This is For the Functional Strategy it is used ion each Worker at the end of running IMWEBs model to calculate the Performance information 
    Input: We just need a Simulation ID and ParameterSet ID 
    Output: It returns a list of list of strings --> each list of strings is actually " a row" in the Performance Table  
    So, in other words, it returns a List of ROWS
    Where this Function is used: At each simulation.
    C# functions: updateIndicatorsTable Funcation which is a big and Complicated function with working with a wide range of Tables -->
    MeasurementID_Lookup_Seed / IMWEBs_Output_Fields_Seed / Performance_Indicators_Seed
        Model_Variable_Seed / and Measurement and Simulation DBs*/
    proc getSimulationPerformanceResults(simID: string, ParsetID: string, slrmpath:string){
        
        var results: list(list(string));
        var SimPer_Insert_command = "dotnet run UpdateIndicatorsTable";
        var SimPer_Insert_input = " ".join(SimPer_Insert_command, ProjectName, "false", hostname, simID, ParsetID, slrmpath, "--project", EFProjectPath);
        var SimPerformance = spawnshell(SimPer_Insert_input, stdout=PIPE);
        var line: string;
        var VariName: string = "test";
        while SimPerformance.stdout.readline(line) {
            if (line.startsWith(VariName) == false ){ 
                for i in line.split("/"){
                    if (i.numBytes > 1){
                        var templist:list(string);
                        for j in i.split(","){
                            templist.append(j);
                        }
                        results.append(templist);
                        VariName = templist[0];
                    }
                }
            }
        }
        SimPerformance.wait();
        if (results.size == 0 || results.size/6 != abs(results.size/6)){
            writeln(here.hostname);
            writeln("Error: Getting Simulation Performance Results!");
        }
        return results;
    }
    /* These functions are for Sensitivity Analysis*/
    proc getSAResults(slrmpath:string){
        
        var results: list(string);
        var command = "dotnet run getSAResults";
        var input = " ".join(command, slrmpath, "--project", EFProjectPath);
        var Performance = spawnshell(input, stdout=PIPE);
        var line: string;
        while Performance.stdout.readline(line) {
            if (line.numBytes > 1){
                for j in line.split(","){
                    results.append(j);
                }
            }
        }
        Performance.wait();
        return results;
    }
    proc UpdateSATable(ParName: string, ParValue: real, SAValues: string, slrmpath:string){

        var Master_command = "dotnet run UpdateSATable";
        var Master_input = " ".join(Master_command, ParName, ParValue:string, SAValues, slrmpath, "--project", EFProjectPath);
        var Master = spawnshell(Master_input);
        Master.wait(); 
    }
    /*---------------------------------------------------------------CHECKED-------------------------------------------------------------*/
    proc getSimulationPerformanceResultsMulti(simID: string, ParsetID: string, obj:string, slrmpath:string){
        
        var results: list(list(string));
        var line: string;
        var TotalFLocal: list(string);
        var VariRef: string = "test";
        var SimPerfoString: string; 
        var FinalString: string; 
        var SimPer_Insert_command = "dotnet run UpdateIndicatorsTable";
        var SimPer_Insert_input = " ".join(SimPer_Insert_command, ProjectName, "false", hostname, simID, ParsetID, slrmpath, "--project", EFProjectPath);
        var SimPerformance = spawnshell(SimPer_Insert_input, stdout=PIPE);
        while SimPerformance.stdout.readline(line) {
            if (line.startsWith(VariRef) == false) { 
                var tempvector: list(list(string));
                var Counter = 1 ;
                for i in line.split("/"){
                    var templist:list(string);
                    if (i.numBytes > 1){
                        for j in i.split(","){
                            templist.append(j);
                        }
                        results.append(templist);
                        if Counter == 1 {
                            tempvector.append(templist);
                            SimPerfoString = ",".join(simID, ParsetID, templist[0], templist[3], templist[5], templist[4]);
                        } else if (templist[0].startsWith(VariRef) == true) {
                            tempvector.append(templist);
                            SimPerfoString = ",".join(SimPerfoString, simID, ParsetID, templist[0], templist[3], templist[5], templist[4]);

                        } else if (templist[0].startsWith(VariRef) == false) {
                            TotalFLocal.append(VariRef);
                            TotalFLocal.append(getSingleObjectiveValue(tempvector, "TotalF", obj):string);
                            SimPerfoString = ",".join(getSingleObjectiveValue(tempvector, "TotalF", obj):string, SimPerfoString);
                            tempvector.clear();
                            tempvector.append(templist);
                            if FinalString.size == 0{
                                FinalString = SimPerfoString;
                            } else {
                                FinalString = "/".join(FinalString, SimPerfoString);
                            }
                            SimPerfoString = ",".join(simID, ParsetID, templist[0], templist[3], templist[5], templist[4]);
                        } 
                        VariRef= templist[0];
                    }
                    Counter = Counter + 1;
                }
                TotalFLocal.append(VariRef);
                TotalFLocal.append(getSingleObjectiveValue(tempvector, "TotalF", obj):string);
                SimPerfoString = ",".join(getSingleObjectiveValue(tempvector, "TotalF", obj):string, SimPerfoString);
                FinalString = "/".join(FinalString, SimPerfoString);
                setLocalPerformanceString(FinalString);
            } 
        }
        setTotalF(TotalFLocal);
        SimPerformance.wait();
        if (results.size == 0 || results.size/6 != abs(results.size/6)){
            writeln(here.hostname);
            writeln("Error: Getting Simulation Performance Results!");
        }
        return results;
    }

    proc getSimulationPerformanceResultsStartPADDS(simID: string, ParsetID: string, obj:string, variable:string, slrmpath:string){
        
        var results: list(list(string));
        var SimPer_Insert_command = "dotnet run UpdateIndicatorsTableFirstPADDS";
        var SimPer_Insert_input = " ".join(SimPer_Insert_command, ProjectName, "false", hostname, simID, ParsetID, variable, slrmpath, "--project", EFProjectPath);
        var SimPerformance = spawnshell(SimPer_Insert_input, stdout=PIPE);
        var line: string;
        var TotalFLocal: list(string);
        var VariRef = variable;
        var SimPerfoString: string; 
        while SimPerformance.stdout.readline(line) {
            var tempvector: list(list(string));
            var Counter = 1;
            for i in line.split("/"){
                var templist:list(string);
                if (i.numBytes > 1){
                    for j in i.split(","){
                        templist.append(j);
                    }
                    results.append(templist);
                    if (Counter == 1) {
                        tempvector.append(templist);
                        SimPerfoString = ",".join(simID, ParsetID, templist[0], templist[3], templist[5], templist[4]);
                    } else {
                        tempvector.append(templist);
                        SimPerfoString = ",".join(SimPerfoString, simID, ParsetID, templist[0], templist[3], templist[5], templist[4]);
                    }
                }
                Counter = Counter + 1;
            }
            TotalFLocal.append(VariRef);
            TotalFLocal.append(getSingleObjectiveValue(tempvector, obj):string);
            SimPerfoString = ",".join(getSingleObjectiveValue(tempvector, obj):string, SimPerfoString);
            
        }
        setTotalF(TotalFLocal);
        setLocalPerformanceString(SimPerfoString);
        SimPerformance.wait();
        if (results.size == 0 || results.size/6 != abs(results.size/6)){
            writeln(here.hostname);
            writeln("Error: Getting Simulation Performance Results!");
        }
        return results;
    }
    /*
    Usage: To calculate the Speed at the end of the program 
    Input: We just need a host anme and Parallelization str
    Output: It returns the total Run time for the Worker it has been called for and also it updates the table
    Where this Function is used: It should be run on the Master Node, when all the workers have done their wors --> Each time this function is called it adds a line to the 
    Computer Performance table for a "Worker node" --> So it should get run as the number of Locales 
    C# functions: comPerformanceUpdate  --> */
    proc Computer_Performance_Info_Update(hostname:string, parallelization:string, slrmPath:string){

        var ComP_Insert_command = "dotnet run ComputerPerformance";
        var ComP_Insert_input = " ".join(ComP_Insert_command, hostname, parallelization, slrmPath, "--project", EFProjectPath);
        var ComPerformance = spawnshell(ComP_Insert_input, stdout=PIPE);
        var line: string;
        var totalRunTime: real;
        while ComPerformance.stdout.readline(line) {
            totalRunTime = line: real; 
        }
        ComPerformance.wait();
        return totalRunTime;
    }

    /*---------------------------------------------------------------CHECKED-------------------------------------------------------------*/
    proc UpdateMasterTablesFunctional(hostname:string, project:string, SimID: string, ParsetID:string, startTD:string, endTD:string, totalrun:real, parameters: list(shared Parameter, parSafe=true), varname: list(string), IndicName:list(string), Indicvalue: list(string), WIndicvalue:list(string), Path:string, averageflow:string){
        
        
        var ParCalIDs: string;
        var ParCurValue: string; 
        for i in parameters do {
            if (ParCalIDs.size == 0){
                ParCalIDs = i.getParametercalID(): string;
                ParCurValue= i.getCurrentValue(): string;
            }
            else {
                ParCalIDs = ",".join(ParCalIDs, i.getParametercalID(): string);
                ParCurValue = ",".join(ParCurValue, i.getCurrentValue(): string);
            }
        }
        var VariablesNames: string;
        var IndicatorNames: string;
        var Indicatorvalues: string;
        var WIndicatorvalues: string;
        for i in 0..#(varname.size){
            if (i == 0){
                VariablesNames = varname[i];
                IndicatorNames = IndicName[i];
                Indicatorvalues = Indicvalue[i];
                WIndicatorvalues = WIndicvalue[i];
            } else {
                VariablesNames = ",".join(VariablesNames, varname[i]);
                IndicatorNames =  ",".join(IndicatorNames, IndicName[i]);
                Indicatorvalues = ",".join(Indicatorvalues, Indicvalue[i]);
                WIndicatorvalues = ",".join(WIndicatorvalues, WIndicvalue[i]);
            }
        }
        var Master_Insert_command = "dotnet run UpdateMasterTables";
        
        var LastPart = " ".join(VariablesNames, IndicatorNames, WIndicatorvalues, Indicatorvalues);
        
        var Master_Insert_input = " ".join(Master_Insert_command, SimID:string, ParsetID, hostname, project, startTD, endTD, totalrun:string, ParCalIDs, ParCurValue, LastPart, Path, averageflow, "--project", EFProjectPath);
        var Master = spawnshell(Master_Insert_input);
        setSimulationIDU(SimID);
        Master.wait();
    }

    /*-----------------Extract Info From Tables ------------------------------------------- */

    /*
    Usage: When we want to find out general information about the Optimisation we want to have for the project at hand.
    Input: NON
    Output: It does not have outputs, but instead, it calls the setter functions and fill the global Variables 
    Where this Function is used: it runs at the beginning of the auto-calibration program to fill the critical variables 
    C# functions: It works with "getOptimizationGeneralInfo" Function, which has the project name as an input (since different projects = different optimization)
    It works with the Optimization_General_Info Table
    */
    /*---------------------------------------------------------------CHECKED-------------------------------------------------------------*/
    proc getOptimizationInfo(SlmPath:string){
        
        var Opt_Command = "dotnet run getOptimizationGeneralInfo";
        var Opt_Input = " ".join(Opt_Command, ProjectName, SlmPath, "--project", EFProjectPath);
        var Opt = spawnshell(Opt_Input, stdout=PIPE);
        var line: string;
        while Opt.stdout.readline(line) {
            var OPT_Info_List: list(string);
            for i in line.split(","){
                OPT_Info_List.append(i);
            }
            for i in 0..#((OPT_Info_List.size / 2) - 1){
                if (OPT_Info_List[i*2] == "Parallelization_Strategy"){
                    setParallelizationStrategy(OPT_Info_List[(i*2)+1]);
                }
                if (OPT_Info_List[i*2] == "MeasureScope"){
                    setMeasureScope(OPT_Info_List[(i*2)+1]);
                }
                if (OPT_Info_List[i*2] == "Calibration_Type"){
                    setCalibrationType(OPT_Info_List[(i*2)+1]);
                }
                if (OPT_Info_List[i*2] == "Calibration_Algorithm_Name"){
                    setCalibrationAlgorithm(OPT_Info_List[(i*2)+1]);
                }
                if (OPT_Info_List[i*2] == "DoInfoExchange"){
                    setDoInfoExchange(OPT_Info_List[(i*2)+1]);
                }
                if (OPT_Info_List[i*2] == "Stopping_Criteria"){
                    setStoppingCriteria(OPT_Info_List[(i*2)+1]);
                }
                if (OPT_Info_List[i*2] == "Exchange_Frequency"){
                    setExchangeFrequency(OPT_Info_List[(i*2)+1]:real);
                }
                if (OPT_Info_List[i*2] == "Number_FArchives_Exchange"){
                    setNumFArchivesExchange(OPT_Info_List[(i*2)+1]:real);
                }
                if (OPT_Info_List[i*2] == "Bound_Archive"){
                    setBoundArchive(OPT_Info_List[(i*2)+1]);
                }
                if (OPT_Info_List[i*2] == "Stopping_Value"){
                    setStoppingValue(OPT_Info_List[(i*2)+1]:real);
                }
                if (OPT_Info_List[i*2] == "Num_Allowed_In_Archive"){
                    setNumAllowedInArchive(OPT_Info_List[(i*2)+1]:real);
                }
                if (OPT_Info_List[i*2] == "MultiObj-Type"){
                    setMultiObjType(OPT_Info_List[(i*2)+1]);
                }
            }
        }
        Opt.wait();
    }

    /* -------------------------Multi- and Single-Objective-------------------------------------- */

    /*
    Usage: This function 1- Updates the archive Tables, and 2- it always Set BestF and BestParSet Variables which can be accessible by their getters 
    2- It updates the Current Sim ID, for the Multi-objective Archive Update if the current Simulation has been added to the Archive 
    Input: NON
    Output: It returns CurrentSimID (added simID to the Archive), Added Parset, and BestF
    Where this Function is used: Always to update archive 
    C# functions: It works with All Dominance, update Archive Functions in the c# 
    */
    /*---------------------------------------------------------------CHECKED-------------------------------------------------------------*/
    proc Archive_Update(parameters: shared ParameterSetInitialization, PreFValue:real, variablename: string, Indicatorname: string, PADDSStart: bool, slmpath:string){

        // This Function updates the archive, and updates the Parmeter set Best values based on the archive update, so, we need to get the Parset and throw it to the Optimization Algorithm 
        var BestF: real= 99;
        if (variablename.isEmpty() == true && Indicatorname.isEmpty() == true && PreFValue != 99 && PADDSStart == false) { /* This is for Single-objective Archive update */
            if (parameters.CheckInitial() == true){
                var archive_Command = "dotnet run UpdateArchive";
                var archive_Input = " ".join(archive_Command, ProjectName, "First", "".join("0", parameters.getHostID():string, parameters.getSimulationID():string), "Normal", slmpath, "--project", EFProjectPath);
                var archiveC = spawnshell(archive_Input);
                var line: string;
                archiveC.wait();
                parameters.changeInitial(false);
                BestF = PreFValue; 
                for par in parameters.getParameterSet(){
                    par.setBestValue(par.getCurrentValue());
                }
                setBestParArchive(parameters.getParameterSet());
            } else {
                var archive_Command = "dotnet run UpdateArchive";
                var archive_Input = " ".join(archive_Command, ProjectName, "NotFirst", "".join("0", parameters.getHostID():string, parameters.getSimulationID():string),"Normal", slmpath, "--project", EFProjectPath);
                var archiveC = spawnshell(archive_Input, stdout=PIPE);
                var line: string;
                while archiveC.stdout.readline(line) {
                    if (line.size != 0) {
                        BestF = line: real;
                    }
                }
                archiveC.wait();
                if (BestF > PreFValue){
                    BestF = PreFValue; 
                } else {
                    for par in parameters.getParameterSet(){
                        par.setBestValue(par.getCurrentValue());
                    }
                }
                setBestParArchive(parameters.getParameterSet());
            }
        } else if (variablename.isEmpty() == true && Indicatorname.isEmpty() == true && PreFValue == 99 && PADDSStart == false) { // PADDS Normal way
            if (parameters.CheckInitial() == true){
                var archive_Command = "dotnet run UpdateArchive";
                var archive_Input: string;
                if (LocalFValue == true) {
                    var LocalPerformance = getLocalPerformanceString();
                    archive_Input = " ".join(archive_Command, ProjectName, "First", parameters.getSimulationID():string, "Normal", slmpath, LocalPerformance, "--project", EFProjectPath);
                } else if (LocalFValue == false) {
                    archive_Input = " ".join(archive_Command, ProjectName, "First", parameters.getSimulationID():string, "Normal", slmpath, "--project", EFProjectPath);
                }
                var archiveC = spawnshell(archive_Input);
                archiveC.wait();
                for par in parameters.getParameterSet(){
                    par.setBestValue(par.getCurrentValue());
                }
                parameters.changeInitial(false); 
            } else {
                var archive_Command = "dotnet run UpdateArchive";
                var archive_Input: string;
                if (LocalFValue == true) {
                    var LocalPerformance = getTotalF();
                    var LocalPerformancee = getLocalPerformanceString();
                    var stringLocalPerformance = LocalPerformance[0];
                    for i in 1..LocalPerformance.size-1 {
                        stringLocalPerformance = ",".join(stringLocalPerformance, LocalPerformance[i]);
                    }
                    archive_Input = " ".join(archive_Command, ProjectName, "NotFirst", parameters.getSimulationID():string, "Normal", slmpath, LocalPerformancee, stringLocalPerformance, "--project", EFProjectPath);
                } else if (LocalFValue == false) {
                    archive_Input = " ".join(archive_Command, ProjectName, "NotFirst", getSimulationIDU(), "Normal", slmpath, "--project", EFProjectPath);
                }
                var archiveC = spawnshell(archive_Input, stdout=PIPE);
                var dominanceStatus: string;
                var currentsimID: string;
                var line: string;
                var counter = 0;
                while archiveC.stdout.readline(line) {
                    writeln(line);
                    if (line.numBytes > 1){ 
                        var temp: list(string);
                        for i in line.split(":"){
                            temp.append(i);
                        }
                        dominanceStatus = temp[0];
                        if (temp[1].startsWith("NON") == false){
                            currentsimID = temp[1];
                        }
                        if (LocalFValue == false){
                            setStoppingMDR(temp[3]: real);
                        }
                    }
                }
                archiveC.wait();
                setDominanceStatus(dominanceStatus);
                if (dominanceStatus.startsWith("ADDED") == true){
                    writeln("-----------------------------------------Dominance Check Passed-----------------------------------------------\n");
                    for par in parameters.getParameterSet(){
                        par.setBestValue(par.getCurrentValue());
                    }
                    setcurentSimID(currentsimID);
                    setBestParArchive(parameters.getParameterSet());
                } else {
                    setBestParArchive(parameters.getParameterSet()); 
                }
            }
        } else if (variablename.isEmpty() == false && Indicatorname.isEmpty() == true && PADDSStart == true){ // PADDS start for either Multi indicator or Multi variable 
            if (parameters.CheckInitial() == true){
                var archive_Command = "dotnet run UpdateArchive";
                var archive_Input: string;
                if (LocalFValue == true) {
                    var LocalPerformance = getLocalPerformanceString();
                    archive_Input = " ".join(archive_Command, ProjectName, "First", parameters.getSimulationID():string, "BeginPADDS", slmpath, PreFValue:string, variablename, LocalPerformance, "--project", EFProjectPath);
                    setcurentSimID(parameters.getSimulationID():string);
                } else if (LocalFValue == false) {
                    archive_Input = " ".join(archive_Command, ProjectName, "First", getSimulationIDU(), "BeginPADDS", slmpath, PreFValue:string, variablename, "--project", EFProjectPath);
                    setcurentSimID(getSimulationIDU());
                }
                var archiveC = spawnshell(archive_Input, stdout=PIPE);
                BestF = PreFValue;
                archiveC.wait();
                for par in parameters.getParameterSet(){
                    par.setBestValue(par.getCurrentValue());
                }
                parameters.changeInitial(false); 
                setBestParArchive(parameters.getParameterSet());
            } else {
                var archive_Command = "dotnet run UpdateArchive";
                var archive_Input: string;
                var dominanceStatus: string;
                var BestParSimID: string;
                var currentSimID: string;
                if (LocalFValue == true) {
                    /* The part for the Local Archive --> Not the first one */
                    var stringLocalPerformance = getLocalPerformanceString();
                    archive_Input = " ".join(archive_Command, ProjectName, "NotFirst", parameters.getSimulationID():string, "BeginPADDS", slmpath, PreFValue:string, variablename, stringLocalPerformance, "--project", EFProjectPath);
                    var archiveC = spawnshell(archive_Input, stdout=PIPE);
                    var line: string;
                    while archiveC.stdout.readline(line) {
                        var temp: list(string);
                        for i in line.split(":"){
                            temp.append(i);
                        }
                        BestF = temp[0]:real;
                        BestParSimID = temp[1];
                    }
                    setBestParArchive(getParameterSetBySimID(BestParSimID, parameters.getParameterSet(), slmpath));
                    currentSimID = BestParSimID;
                    //currentSimID = parameters.getSimulationID():string;
                    archiveC.wait();
                } else if (LocalFValue == false) {
                    /* The part for the Master Archive --> Not the first one */
                    archive_Input = " ".join(archive_Command, ProjectName, "NotFirst", getSimulationIDU(), "BeginPADDS", slmpath, PreFValue:string, variablename,"--project", EFProjectPath);
                    var archiveC = spawnshell(archive_Input, stdout=PIPE);
                    var line: string;
                    while archiveC.stdout.readline(line) {
                        if (line.numBytes > 1){ 
                            var temp: list(string);
                            for i in line.split(":"){
                                temp.append(i);
                            }
                            dominanceStatus = temp[1];
                            if (temp[2].startsWith("NON") == false){
                                currentSimID =  temp[2];
                            }
                            if (dominanceStatus == "ADDED"){
                                BestF = temp[0]: real;
                            }
                        }
                    }
                    archiveC.wait();
                }
                //check
                if (BestF != 99){
                    for par in parameters.getParameterSet(){
                        par.setBestValue(par.getCurrentValue());
                    }
                }
                if (currentSimID.size != 0){
                    setcurentSimID(currentSimID);
                }
                setDominanceStatus(dominanceStatus);
                setBestParArchive(parameters.getParameterSet());
            }
        } else if (variablename.isEmpty() == false && Indicatorname.isEmpty() == false && PADDSStart == true){
            var BestF: real = 99;
            if (parameters.CheckInitial() == true){
                var archive_Command = "dotnet run UpdateArchive";
                var archive_Input: string;
                if (LocalFValue == true) {
                    var LocalPerformance = getLocalPerformanceString();
                    archive_Input = " ".join(archive_Command, ProjectName, "First", parameters.getSimulationID():string, "BeginPADDS",  PreFValue:string, variablename, Indicatorname, LocalPerformance, slmpath, "--project", EFProjectPath);
                } else if (LocalFValue == false) {
                    archive_Input = " ".join(archive_Command, ProjectName, "First", parameters.getSimulationID():string, "BeginPADDS",  PreFValue:string, variablename, Indicatorname, slmpath, "--project", EFProjectPath);
                }
                var archiveC = spawnshell(archive_Input, stdout=PIPE);
                var line: string;
                while archiveC.stdout.readline(line) {
                    BestF = line: real;
                }
                archiveC.wait();
                for par in parameters.getParameterSet(){
                    par.setBestValue(par.getCurrentValue());
                }
                parameters.changeInitial(false); 
                setcurentSimID(parameters.getSimulationID():string);
                setBestParArchive(parameters.getParameterSet());
            } else {
                var archive_Command = "dotnet run UpdateArchive";
                var archive_Input: string;
                var dominanceStatus: string;
                var currentSimID: string;
                if (LocalFValue == true) {
                    /* The part for the Local Archive --> Not the first one */
                    var stringLocalPerformance = getLocalPerformanceString();
                    archive_Input = " ".join(archive_Command, ProjectName, "NotFirst", parameters.getSimulationID():string, "BeginPADDS",  PreFValue:string, variablename,  Indicatorname, stringLocalPerformance, slmpath, "--project", EFProjectPath);
                    var archiveC = spawnshell(archive_Input, stdout=PIPE);
                    var line: string;
                    while archiveC.stdout.readline(line) {
                        BestF = line: real;
                    }
                    archiveC.wait();
                } else if (LocalFValue == false) {
                    /* The part for the Master Archive --> Not the first one */
                    archive_Input = " ".join(archive_Command, ProjectName, "NotFirst", getSimulationIDU(), "BeginPADDS",  PreFValue:string, variablename, Indicatorname, slmpath, "--project", EFProjectPath);
                    var archiveC = spawnshell(archive_Input, stdout=PIPE);
                    var line: string;
                    while archiveC.stdout.readline(line) {
                        if (line.numBytes > 1){ 
                            writeln(line);
                            var temp: list(string);
                            for i in line.split(":"){
                                temp.append(i);
                            }
                            dominanceStatus = temp[1];
                            if (temp[2].startsWith("NON") == false){
                                currentSimID =  temp[2];
                            }
                            if (dominanceStatus == "ADDED"){
                                BestF = temp[0]: real;
                            }
                        }
                    }
                    archiveC.wait();
                }
                
                if (BestF != 99){
                    for par in parameters.getParameterSet(){
                        par.setBestValue(par.getCurrentValue());
                    }
                    if (currentSimID.size == 0){
                        setcurentSimID(parameters.getSimulationID():string);
                    } else {
                        setcurentSimID(currentSimID);
                    }
                }
                setDominanceStatus(dominanceStatus);
                setBestParArchive(parameters.getParameterSet());
            }
        }
        setBestF(BestF);
    }
    /* -------------------------Multi-Objective / Island-based-------------------------------------- */

    /*
    Usage: When we want to find out what type of Multi-calibration we have and what are the names of objectives we have. This is critical since for the beginning of the PADDS
    algorithm, we need to run DDS for each of these objectives and "optimize" them. Then, when all of them has been optimized --> We need to do crowding distance to pick one out and start the actual PADDS with it.
    Input: NON -->
    Output: A List of Strings --> [Type_of_multi, Var1:number, Indi_forVar1:number, ....]
    Where this Function is used: For the Functional Strategy,on the master node for the beginning of the PADDS
    C# functions: It works with "getObjectivesNames" Function, which has the project name as an input (since different projects = different calibrations
        It works with the Optimization_General_Info and Performance_Indicators_Seed Tables
    */

    /*---------------------------------------------------------------CHECKED-------------------------------------------------------------*/
    proc getMultiObjectiveNames(slrmpath:string){

        var MO_Command = "dotnet run getObjectivesNames";
        var MO_Input = " ".join(MO_Command, ProjectName, slrmpath, "--project", EFProjectPath);
        var MO = spawnshell(MO_Input, stdout=PIPE);
        var line: string;
        var ObjectivesNames: list(string);
        while MO.stdout.readline(line) {
            for i in line.split(","){
                if (i.numBytes > 1){
                    ObjectivesNames.append(i);
                }
            }
        }
        MO.wait();
        return ObjectivesNames; 
    }
    /*
    Usage: When we want to calculate the Crowding Distance Parameter Set --> This Parameter Set is the ParamterSet that we want to send to all the machines which is the actual Start point of PADDS
    This parameter set is one selection from all the parameter sets that each individually had been updated for optimizing a single Objective
    Input: a Paramterset --> It actually runs Crowding Distance and then updates the Current Values of the given Paramterset with the found Crowding Distance Parameter set 
    Output: Updated Parameterset  
    Where this Function is used: For the Functional Strategy, On the Master Node, when we want to do crowding distance 
    C# functions: It works with "Crowdingdistnace()" Function, which does not have any input: It works with the BestParameterSet_Archive Table
    */

    /*---------------------------------------------------------------CHECKED-------------------------------------------------------------*/
    proc CrowdingDistance(parameters:list(shared Parameter, parSafe=true), multiobjectivetype: string, slrmpath:string){
        
        var CD_Command = "dotnet run crowdingDis";
        var TempSet: list(shared Parameter, parSafe=true);
        assert(TempSet.type == parameters.type);
        TempSet = parameters;
        var CD_Input = " ".join(CD_Command, multiobjectivetype, slrmpath, "--project", EFProjectPath);
        var CD = spawnshell(CD_Input, stdout=PIPE);
        var line: string;
        while CD.stdout.readline(line) {
            var Temp: list(string);
            for i in line.split(","){
                for j in i.split(":"){
                    if (j.numBytes > 1){
                        Temp.append(j);
                    }
                }
            }
            for par in TempSet{
                if (Temp[1]: real == par.getParametercalID()){
                    par.setCurrentValue(Temp[3]: real);
                    par.setBestValue(Temp[3]: real);
                }
            }
        }
        CD.wait();
        return TempSet;
    }
    /*
    Usage: When we want to get the Archive of the Current Solution for PADDS --> The Current Solution is identified by a Simulation ID (Current Sim ID) 
    The Current solution's importance is that this solution is the one that should be used for updating and running the model for the next simulation
    The current solution is one that is added last tho the Archive 

    Input: Current Simulation ID
    Output: The output is a list of strings which is the archive associated with  the Simulation ID --> Each item is ObjectiveName: ObjectiveValue 
    Where this Function is used: For the Functional Strategy, This Function is used after each Model Run on the Worker node, to identify which parameter set should be used for the next simulation 
    C# functions: It works with "archivebysimId"  Function, which gets SimulationID and ProjectName: It works with the OptimziationInfo Table, to identify the Type of the calibration 
    and It returns the Objective Names and the Values associated with them, from the BestArchive Table 
    */
    /*---------------------------------------------------------------CHECKED-------------------------------------------------------------*/

    proc LocalParsetUpdate(parameters:list(shared Parameter, parSafe=true), fbest: real, slmPath:string, fvalues:list(string), simID: string, calType: string, Mnodes: int){

        var ParNames:string;
        var ParValues:string;
        var fvalueString: string;
        var resultsBPS: list(list(shared Parameter, parSafe=true));
        var nodes = Mnodes;
        var Parameterset = parameters;
        for par in parameters{
            if (ParNames.size == 0){
                ParNames = par.getParName();
                ParValues = par.getCurrentValue():string;
            } else {
                ParNames = ",".join(ParNames, par.getParName());
                ParValues = ",".join(ParValues, par.getCurrentValue():string);
            }
        }
        var CD_Input: string;
        if (fvalues.size != 0){
            for i in 0..fvalues.size-1{
                if (fvalueString.size == 0){
                    fvalueString = fvalues[i];
                } else {
                    fvalueString = ",".join(fvalueString, fvalues[i]);
                }
            }
            nodes = 1;
            var CD_Command = "dotnet run UpdateLocalParSetsIndivDist";
            CD_Input = " ".join(CD_Command, ParNames, ParValues, fbest:string, Parameterset.size:string, slmPath, fvalueString, simID, calType, "KGE_Method", "--project", EFProjectPath);

        } else {
            var CD_Command = "dotnet run UpdateLocalParSetsMasterNode";
            CD_Input = " ".join(CD_Command, slmPath, simID, "KGE_Method", nodes: string, "--project", EFProjectPath);
        }

        var CD = spawnshell(CD_Input, stdout=PIPE);
        var line: string;
        var Temp: list(string);
        while CD.stdout.readline(line) {
            for i in line.split(","){
                for j in i.split(":"){
                    Temp.append(j);
                }
            }
        }
        CD.wait();
        if (nodes == 1) {
            for i in 0..(Temp.size/13-1) {
                for par in Parameterset{
                    if (par.getParName().startsWith(Temp[(i*13) + 1]) == true){
                        par.setBestValue(Temp[(i*13) + 3]:real);
                        par.setSTD(Temp[(i*13) + 5]:real);
                        par.setRange(Temp[(i*13) + 9]:real);
                        par.setUseRange(Temp[(i*13) + 11]:int);
                    }
                }
                setFlowAverage(Temp[(i*13) + 7]);
            }
            setMasterBestParsetsSingle(Parameterset);
        }
        else {
            for j in 0..(nodes-1){
                for i in 0..(Temp.size/(15*nodes)-1) {
                    for par in Parameterset{
                        if (par.getParName().startsWith(Temp[(i*15*nodes) + j*15 + 1]) == true){
                            par.setBestValue(Temp[(i*15*nodes) + j*15 + 3]:real);
                            par.setCurrentValue(Temp[(i*15*nodes) + j*15 + 3]:real);
                            par.setSTD(Temp[(i*15*nodes) + j*15 + 5]:real);
                            par.setRange(Temp[(i*15*nodes) + j*15 + 9]:real);
                            par.setUseRange(Temp[(i*15*nodes) + j*15 + 11]:int);
                        }
                    }
                    setFlowAverage(Temp[(i*15*nodes) + j*15 + 7]);
                    setStopAlgorithm(Temp[(i*15*nodes) + j*15 + 13]:int);
                }
                resultsBPS.append(Parameterset);
            }
        }
        if (resultsBPS.size != 0) {
            setMasterBestParsets(resultsBPS);
        }
    }
    proc IslandLocalParsetUpdate(parameters:list(shared Parameter, parSafe=true), fbest: real, slmPath:string, fvalues:list(string), simID: string, calvar: string){

        var ParNames:string;
        var ParValues:string;
        var fvalueString: string;
        var CD_Command: string; 
        var resultsBPS: list(list(shared Parameter, parSafe=true));
        for par in parameters{
            if (ParNames.size == 0){
                ParNames = par.getParName();
                ParValues = par.getCurrentValue():string;
            } else {
                ParNames = ",".join(ParNames, par.getParName());
                ParValues = ",".join(ParValues, par.getCurrentValue():string);
            }
        }
        for i in 0..fvalues.size-1{
            if (fvalueString.size == 0){
                fvalueString = fvalues[i];
            } else {
                fvalueString = ",".join(fvalueString, fvalues[i]);
            }
        }
        if (calvar != "ALL"){
            CD_Command = "dotnet run UpdateLocalonIslands";
        } else {
            CD_Command = "dotnet run UpdateLocalonIslandsPADDS";
        }
        var CD_Input = " ".join(CD_Command, ParNames, ParValues, fbest:string, parameters.size:string, slmPath, fvalueString, simID, calvar, "PBIAS_Method", "--project", EFProjectPath);
        var CD = spawnshell(CD_Input, stdout=PIPE);
        var line: string;
        var Temp: list(string);
        while CD.stdout.readline(line) {
            for i in line.split(","){
                for j in i.split(":"){
                    Temp.append(j);
                }
            }
        }
        CD.wait();
        for i in 0..(Temp.size/13-1) {
            for par in parameters{
                if (par.getParName().startsWith(Temp[(i*13) + 1]) == true){
                    par.setBestValue(Temp[(i*13) + 3]:real);
                    par.setSTD(Temp[(i*13) + 5]:real);
                    par.setRange(Temp[(i*13) + 9]:real);
                    par.setUseRange(Temp[(i*13) + 11]:int);
                }
            }
            setFlowAverage(Temp[(i*13) + 7]);
        }
        setMasterBestParsetsSingle(parameters);
    } 
    proc setFlowAverage(value:string){
        this.FlowAverage = value;
    }
    proc getFlowAverage(){
        return this.FlowAverage;
    }

    /*---------------------------------------------------------------CHECKED-------------------------------------------------------------*/
    proc getanArchivebySimID(simID:string, slrmpath:string){
        
        var Arch_Command = "dotnet run getArchiveById";
        var Arch_Input = " ".join(Arch_Command, simID:string, ProjectName, slrmpath, "--project", EFProjectPath);
        var Arch = spawnshell(Arch_Input, stdout=PIPE);
        var line: string;
        var archive: list(string);
        while Arch.stdout.readline(line) {
        
            var OPT_Info_List: list(string);
            for i in line.split(","){
                for j in i.split(":"){
                    OPT_Info_List.append(j);
                }
            }
            for i in 0..((OPT_Info_List.size / 3) - 1){
                if (OPT_Info_List[(i*3)+1] != "NONE"){ // It is a Multi-VarIndicator Calibration
                    var partF = "".join(OPT_Info_List[(i*3)], OPT_Info_List[(i*3) + 1]);
                    archive.append(":".join(partF, OPT_Info_List[(i*3)+2]));
                }
                else {
                    archive.append(":".join(OPT_Info_List[(i*3)], OPT_Info_List[(i*3) + 2]));
                }
            }
        }
        Arch.wait();
        return archive;
    }
    /*
    Usage:when we have some Archives (as the List of Strings), then, we want to check their dominance and select one based on the Crowding Distance We need to use this Function 
    Input: 1- A list of Archives (Each archive is a list of string --> Each elemnet is ObjectiveName:ObjectiveValue) 2- An ID for each Archive to be able to differentiate them (the order of two inputs should be the same)
    Output: The output is teh ID of the Archive which is 1- Non dominated 2- has teh max crowding distnace 
    Where this Function is used: For the Functional Strategy, where we want to compare the Local Archive Current Solution with the Master Archive Current solution 
    C# functions: It does not have any c# functions 
    */
    proc DominanceCheckAndFinalSolFind(solustions: list(list(string)), hoistid: list(real)){

        /* We have a list of list of strings and we want to sort all of them based on the Objectives' names; therefore, on all lists, the first item, for example, is the same objective's values  */
        var returnVal: int;
        var FinalSolutions: list(list(real)); /* For storing Non-Dominated solutions */
        var FirstItem = solustions.getValue(0); // Getting the First Archive, which is the base for Comparison 
        var solutionsx = solustions; 
        solutionsx.remove(solutionsx.getValue(0));
        var FirstSize = FirstItem.size - 1; // Get the archive's Indices Maximum
        var FirstSol: list(string);
        var FirstsolFinal: list(real);
        var finalHostID: list(real);
        var ObjectiveNames: list(string);
        for i in 0..FirstSize{
            var tempS: list(string);
            for j in FirstItem[i].split(":"){
                FirstSol.append(j); 
                tempS.append(j);
            }
            FirstsolFinal.append(tempS[1]:real); // Just Objective Values in an order 
            ObjectiveNames.append(tempS[0]);
        }

        FinalSolutions.append(FirstsolFinal);
        finalHostID.append(hoistid[0]); // Getting the IDs 
        for next in solutionsx { // Here we are iterating over all archives and making their order exactly as the same order that the first Archive has 
            var secondsol: list(real);
            secondsol = FirstsolFinal;
            for i in 0..FirstSize{
                var temp: list(string);
                for j in next[i].split(":"){
                    temp.append(j);
                }
                for k in 0..ObjectiveNames.size-1{
                    if (ObjectiveNames[k] == temp[0]){
                        secondsol.set(k, temp[1]: real);
                    }
                }
            }
            FinalSolutions.append(secondsol);
            finalHostID.append(hoistid[solutionsx.indexOf(next) + 1]); // 1 because we have removed the first archive from the solutions list 
        }
        /* Now we have List of objective values exactly with the same order */ 

        var dominanceAlist: list(bool);
        var dominanceBlist: list(bool); 
        var removed: list(list(real));
        var nondominated: list(list(real));

        // Now we want to check the Dominance
        var solSize: int;
        var refS = FinalSolutions; 
        for sol in FinalSolutions { 
            for solution in refS {
                solSize = solution.size - 1;
                var checksameness: list(bool);
                for i in 0..solSize {
                    if (sol[i] == solution[i]){
                        checksameness.append(true);
                    }
                }
                if (checksameness.size != FirstItem.size){ // They are not the same Solutions 
                    for i in 0..solSize {
                        if (sol[i] <= solution[i]){ 
                            dominanceAlist.append(true);
                        }
                        if (sol[i] < solution[i]){
                            dominanceBlist.append(true);
                        }
                    }
                    var DominatedF = false;
                    var DominatedS = false;
                    if (dominanceAlist.size == solution.size) {
                        if (dominanceBlist.size != 0){
                            removed.append(solution);
                            writeln("One Solution Dominated the other (1)");
                            DominatedF = true;
                        }
                    }
                    if (dominanceAlist.size == 0){
                        removed.append(sol);
                        writeln("One Solution Dominated the other (2)");
                        DominatedS = true;
                    }
                    if (DominatedS == false &&  DominatedF == false){
                        nondominated.append(sol);
                        nondominated.append(solution);
                        writeln("We have nondominated solustions");
                    }
                } else {
                    refS.remove(solution);
                }
            }
        }   
        for non in nondominated { // We want to remove Dominated Solutions 
            for rem in removed {
                var n = rem.size - 1;
                var checksameness: list(bool);
                for i in 0..n {
                    if (rem[i] == non[i]){
                        checksameness.append(true);
                    }
                }
                if (checksameness.size == n && checksameness.contains(false) == false){
                    nondominated.remove(non);
                }
            }
        }
        /* Here I want to do Crowding distance */
        /* We have to select one Solution from the non-dominated solutions */ 
        /* This record saves the Crowding Distance of the archives */ 
        if (nondominated.size == 0){
            returnVal = 1;
        } else if (nondominated.size == 1) {
            writeln("I am in Dominace in 1 size");
            for x in nondominated[0]{
                writeln(x);
            }
            var nond = nondominated[0];
            returnVal = finalHostID[FinalSolutions.indexOf(nondominated.getValue(0))]: int ;
        } else if (nondominated.size > 1) {
            writeln("I am in Dominace in 2 size");
            record CDsvalue{
                var IDs: real;
                var CDValue: real;
            }
            var listCDs: list(CDsvalue);
            for non in nondominated {
                var Recorditem: CDsvalue;
                Recorditem.IDs = nondominated.indexOf(non);
                Recorditem.CDValue = 0;
                listCDs.append(Recorditem);
            }
            /* Here we calculate Crowding Distance for each solution*/
            for obj in 0..solSize{
                var objlist: list(real);
                var max = 0:real;
                var min = 0:real;
                if (nondominated.size > 2){
                    for item in nondominated{
                        objlist.append(item[obj]);
                        if (item[obj] > max){
                            max = item[obj];
                        }
                        if (item[obj] < min){
                            min = item[obj];
                        }
                    }
                } else if (nondominated.size == 2){
                    if (nondominated[0][obj] > nondominated[1][obj]){
                        max = nondominated[0][obj];
                        min = nondominated[1][obj];
                    } else {
                        max = nondominated[1][obj];
                        min = nondominated[0][obj];
                    }
                    objlist.append(nondominated[1][obj]);
                    objlist.append(nondominated[0][obj]);
                }
                objlist.sort();
                var objsize = objlist.size - 1;
                for i in 0..objsize{
                    for item in nondominated{
                        if (item[i] == objlist[i]){
                            for rec in listCDs {
                                writeln("I am in Checing CDs");
                                if (rec.IDs == nondominated.indexOf(item)){
                                    var preval = rec.CDValue;
                                    if (nondominated.size  == 2){
                                        writeln("yopuhh two ");
                                        if (objlist[i] == max){
                                            rec.CDValue = 0 + preval;
                                        } else {
                                            rec.CDValue = 1000 + preval;
                                        } 
                                    } else {
                                        writeln("yopuhh one ");
                                        if (objlist[i] != min && objlist[i] != max){
                                            var cd = (objlist[i+1] - objlist[i])/(max-min);
                                            rec.CDValue = cd + preval;
                                        } else {
                                            rec.CDValue = rec.CDValue + 1000;
                                        }
                                    }
                                    
                                }
                            }
                        }
                    }
                }
            }
            var maxCD = 0:real;
            var FinalID: real;
            for item in listCDs{
                if (item.CDValue > maxCD){
                    maxCD = item.CDValue;
                    FinalID = item.IDs;
                    writeln("I am in MAX CDs");
                }
            }
            var CheckSolHostId: list(bool);
            var selectedSol = nondominated.getValue(FinalID:int);
            for sol in FinalSolutions{
                writeln("I am in Checking finalsool ");
                for i in 0..solSize{
                    for j in 0..solSize {
                        if (sol[i] == selectedSol[j]){
                            CheckSolHostId.append(true);
                        }
                    }
                }
                if (CheckSolHostId.size == solSize){
                    returnVal =  finalHostID[FinalSolutions.indexOf(sol)]: int ;
                    writeln(" This is the winner of the CDs");
                    writeln(returnVal);
                    break;
                } else {
                    CheckSolHostId = new list(bool);
                }
            }  
        }
        return returnVal;
    }
    /*
    Usage: when we have  added shared Knowledge to our archive and we have done crowding distance with all of them and the last simulation we had
    we get the simID for which we need to get parameter set and continue with it, we throw that Sim ID and the previous parset we had to this function, 
    to get the parameters' Current value and the Best value updated
    Input: 1- Simulation ID, 2- the previous Parameter set 
    Output: teh updated paramtesret set 
    Where this Function is used: For the Island-based Strategy, where we want to get a new parset after adding the shared knowledge 
    C# functions: It does not have any c# functions 
    */
    /*---------------------------------------------------------------CHECKED-------------------------------------------------------------*/
    proc getParameterSetBySimID(SimID: string, parameters: list(shared Parameter, parSafe=true), path:string) {

        var Command = "dotnet run getParameterSetBySimID";
        var Input = " ".join(Command, SimID:string, path, "--project", EFProjectPath);
        var ParSet = spawnshell(Input, stdout=PIPE);
        var line: string;
        while ParSet.stdout.readline(line) {
            if (line.numBytes > 1){ 
                var Temp: list(string);
                for i in line.split(","){
                    for j in i.split(":"){
                        Temp.append(j);
                    }
                }
                for par in parameters {
                    if (Temp[1]:real == par.getParametercalID()){
                        par.setCurrentValue(Temp[3]:real);
                        par.setBestValue(Temp[3]:real);
                    }
                }
            }
        }
        ParSet.wait();
        return parameters;
    }

    /*---------------------------------------------------------------CHECKED-------------------------------------------------------------*/
    proc getValueForStoppingCriterionSTD(Multitype: string, Path:string){
        
        
        var Command = "dotnet run getSTDofobjectives";
        var Input = " ".join(Command, Multitype, Path, "--project", EFProjectPath);
        var ParSet = spawnshell(Input, stdout=PIPE);
        var line: string;
        var StatsResults: list(string);
        while ParSet.stdout.readline(line) {
            for i in line.split(","){
                for j in i.split(":"){
                    
                    StatsResults.append(j);
                }
            }
        }
        ParSet.wait();
        return StatsResults;
    }


    /* Multi-objective - This a record type for storing a solution for a multi-objective Calibration for exchange purposes */
    
    record nondominatedArchiveElement {
        var SimulationID: real;
        var ProjectName: string;
        var Variable_Name: string;
        var TotalFValue: real;
        var Indicator_Name: list(string);
        var Indicator_Value: list(real);
        proc init(){
            this.SimulationID = 0;
            this.Variable_Name="";
            this.TotalFValue=0;
            Indicator_Name = new list(string);
            Indicator_Value  = new list(real);
        }
        proc init(simID:string){
            this.SimulationID = simID;
        }
        proc getSimulationID(){
            return this.SimulationID;
        }
        proc setSimulationID(value:real){
            this.SimulationID = value;
        }
        proc getProjectName(){
            return this.ProjectName;
        }
        proc setProjectName(value: string){
            this.ProjectName = value;
        }
        proc getVariable_Name(){
            return this.Variable_Name;
        }
        proc setVariable_Name(value:string){
            this.Variable_Name = value;
        }
        proc getTotalFValue(){
            return this.TotalFValue;
        }
        proc setTotalFValue(value:real){
            this.TotalFValue = value;
        }
        proc getIndicator_Name(){
            return this.Indicator_Name;
        }
        proc setIndicator_Name(value:string){
            this.Indicator_Name.append(value);
        }
        proc getIndicator_Value(){
            return this.Indicator_Value;
        }
        proc setIndicator_Value(value:real){
            this.Indicator_Value.append(value);
        }
    }
    /*
        ------------Island-based Architecture --> Get Exchange Info for Multi-Objective Calibration ----------- 

    Usage: This function takes a number of Archives (numSolustions) from the Best_Archive Table and each archive will be saved as  record nondominatedArchiveElement, then all these nondominatedArchiveElements
    will be added to a list and will be returned by the function 
    Input: How many archives should be exchanged? 
    Output: A list of nondominatedArchiveElement records 
    Where this Function is used:  At the Identified simulation numbers where the exchange info should take place --> On all Islands 
    C# functions: It works with "ExchangeMultiCalibration" Function,
    It works with the BestParameterSet_Archive Table
    */
    proc getBestExchangeArchive(numSolutions:int){
        
        var FBest_Command = "dotnet run ExchangeMultiCalibration";
        var FBest_Input = " ".join(FBest_Command, ProjectName, numSolutions:string, "--project", EFProjectPath);
        var FBest = spawnshell(FBest_Input, stdout=PIPE);
        var line: string;
        var ExchangeArchive: list(nondominatedArchiveElement);
        while FBest.stdout.readline(line) {
            var Temp: list(string);
            for i in line.split(","){
                Temp.append(i);
            }
            var SRec = new nondominatedArchiveElement(Temp[1]: real);
            SRec.setProjectName(Temp[0]); 
            SRec.setVariable_Name(Temp[2]);
            SRec.setTotalFValue(Temp[3]:real);
            SRec.setIndicator_Name([Temp[4]]);
            SRec.setIndicator_Value(Temp[5]:real);
            ExchangeArchive.append(SRec);
        }
        FBest.wait();
        
        if (ExchangeArchive.size == 0){
            writeln("There is a problem with Exchanging Creating records of non dominated solutions from Locale %s", here.hostname);
        }
        return ExchangeArchive;
    }

    proc getValueForCrowdingDistanceSTD(Multitype: string, Path:string){
    
        var Command = "dotnet run getCrowdingDistanceObjF";
        var Input = " ".join(Command, Multitype, Path,  "--project", EFProjectPath);
        var ParSet = spawnshell(Input, stdout=PIPE);
        var line: string;
        var StatsResults: real;
        while ParSet.stdout.readline(line) {
            StatsResults = line: real;
        }
        ParSet.wait();
        return StatsResults;
    }
    /*
    Usage: At the end of each simulation, when the measure scope is Speed, we need to figure out if we need to stop the Algorithm from exploring the space.
    Thus, in the case that we have the Pareto Front, we have to calculate the Min distance of the current Archive that we have to the Pareto Front.
    This value is called GD (Generational Distance) and if this is small enough, we need to cease the algorithm
    Input: 1- Multi-objective type 
    Output: The GD value 
    Where this Function is used: For the Island-based Strategy, and functional str when working with Multi-objective algorithm
    C# functions: GenerationalDistnace and Best archive and ParetoFront tables  
    */
    proc gettheGDValue(MultiType:string){
        var Command = "dotnet run getTheGDValue";
        var Input = " ".join(Command, MultiType, ProjectName, "--project", EFProjectPath);
        var ParSet = spawnshell(Input, stdout=PIPE);
        var line: string;
        var GDValue: real;
        while ParSet.stdout.readline(line) {
            GDValue = line: real;
        }
        ParSet.wait();
        return GDValue;
    }
    /*
    Usage: This function is called whenever the island wants to get a list of archive elements based on the idea of the "Epsilon-indicator" and share them with other islands
    Input: This function gets the multiobjective type, and the number of archives that machines should share with each other 
    Output: In fact this function calls two setter functions and adds a list of 1- shared parameter sets 2- shared archives 
    Where this Function is used: For the Dependent Multi-search Strategy, where we want to share knowledge with other machines
    C# functions: ExchangeArchiveSetBasedonepsilon Function,
    */
    
    proc GetExchangeData(Multitype: string, ExchangeMethod: string, numberArchive: real){

        var Arch_Command = "dotnet run readExternalArchivesFromTable";
        var ParsetListL: list (EpsilonParset);
        var ArchivesListL: list(EpsilonArchive);
        var Arch_Input = " ".join(Arch_Command, ProjectName, numberArchive: string, ExchangeMethod,  "--project", EFProjectPath);
        var Arch = spawnshell(Arch_Input, stdout=PIPE);
        var line: string;
        var Id = 1; 
        while Arch.stdout.readline(line) {
            var OPT_Info_List: list(string);
            for i in line.split(",,"){
                OPT_Info_List.append(i);
            }
            var Parset: EpsilonParset;
            Parset.ParSetID = Id;
            var Archive: EpsilonArchive;
            Archive.ParsetID = Id;

            var Parsetpart: list(string);
            for i in  OPT_Info_List[0].split(","){
                for j in i.split(":"){
                    Parsetpart.append(j);
                }
            }
            var Archivepart: list(string);
            for m in 0..#((Parsetpart.size / 2) - 1){
                Parset.ID.append(Parsetpart[2*m]: real);
                Parset.value.append(Parsetpart[(2*m) + 1]: real);
            }
            for i in  OPT_Info_List[1].split("::"){
                for j in i.split(","){
                    for k in j.split(":"){
                        Archivepart.append(k);
                    }
                }
            }
            if (Multitype == "Multi-VarIndicator"){
                for m in 0..#((Archivepart.size/4) - 1){
                    Archive.IndicatorName.append(Archivepart[(4*m) + 2]);
                    Archive.IndicatorValue.append(Archivepart[(4*m) + 3]: real);
                    Archive.variablename.append(Archivepart[(4*m)]);
                    Archive.variableFtotal.append(Archivepart[(4*m) + 1]: real);
                }
            } else {
                for m in 0..#((Archivepart.size/4) - 1){
                    Archive.IndicatorName.append(Archivepart[4*m]);
                    Archive.IndicatorValue.append(Archivepart[(4*m) + 1]: real);
                    Archive.variablename.append(Archivepart[(4*m) + 2]);
                    Archive.variableFtotal.append(Archivepart[(4*m) + 3]: real);
                }
            }
            ParsetListL.append(Parset);
            ArchivesListL.append(Archive);
            Id = Id +1;
        }
        Arch.wait();
        setParsetList(ParsetListL);
        setArchivesList(ArchivesListL);
    }
    /*
    Usage: This function is called whenever the island wants to read the sahred knowledge --> 1- check the dominance of them with its archive, 3- do the crowding distance with the non-dominated ones and the last 
    solution it has and 4- get the simulation ID which is the ID of parameter set that the machine should continue with 
    Input: The input data is actually the shared knowledge and the type of multi-objective, the type of archive and the host ID of the machine which has shared this info with the current machine 
    Output: is the simulation ID, that machine should get it and reads the parameter set from its table based on this simulation ID  
    Where this Function is used: For the Dependent Multi-search Strategy, where we want read the shared knowledge
    C# functions: readExchangeArchive, Crowdingdistnace Functions,
    */
    proc WriteEpsilonExchangeData(EpsilonParsett: list(EpsilonParset), EpsilonArchivee: list(EpsilonArchive), multitype: string, boundcheck:bool, hostidcomputersharedthis: real) {

        // We need to check if the sizes are the same 
        var Arch_Command = "dotnet run readExternalArchivesToTable";
        var Arch_Input: string; 
        var SimIDCurrent: string;
        if (EpsilonParsett.size == EpsilonArchivee.size){
            var ParsetString: list(string);
            var ArchiveString: list(string);
            var IDs: list(real);
            for par in EpsilonParsett{
                IDs.append(par.ParSetID);
            }
            var numvar: list(string);
            for archive in EpsilonArchivee{
                if (IDs[0] == archive.ParsetID){
                    for vari in archive.variablename{
                        if (numvar.contains(vari) == false){
                            numvar.append(vari);
                        }
                    }
                }
            }
            if (multitype == "Multi-Indicator"){
                
                for id in IDs {
                    var paraset: string;  // String representing Parametersets 
                    var archInd: string; // String representing Indicators 
                    var archvar: string; // String representing Variables
                    for par in EpsilonParsett{
                        if (id == par.ParSetID){
                            if (paraset.size == 0){
                                paraset = ",".join(par.ID:string, par.value:string);
                            } else{
                                paraset = ",".join(paraset, par.ID:string, par.value:string);
                            }
                        }
                    }
                    for archive in EpsilonArchivee{
                        if (id == archive.ParsetID){
                            var sizeind = archive.IndicatorName.size -1;
                            for i in 0..sizeind{
                                if (archInd.size == 0){
                                    archInd= ",".join(archive.IndicatorName[i], archive.IndicatorValue[i]: string);
                                } else {
                                    archInd= ",".join(archInd, archive.IndicatorName[i], archive.IndicatorValue[i]: string);
                                }
                            }   
                            if (archvar.size == 0){
                                archvar= ",".join(archive.variablename[0], archive.variableFtotal[0]:string);
                            }
                        }
                    }
                    ParsetString.append(paraset);
                    ArchiveString.append(":".join(archInd, archvar));
                }
                var stringF: string = ParsetString[0];
                var n = ParsetString.size -1;
                var stringS: string = ArchiveString[0];
                for i in 1..n{
                    stringF = "|".join(stringF, ParsetString[i]);
                    stringS = "|".join(stringS, ArchiveString[i]);
                }
                var Arch_Input = " ".join(Arch_Command, multitype, stringS , stringF, boundcheck:string, hostidcomputersharedthis:string, "--project", EFProjectPath);
            }
            if (multitype =="Multi-Variable"){
        
                for id in IDs {
                    var paraset: string;  
                    var archInd: string; 
                    var archvar: string; 
                    for par in EpsilonParsett{
                        if (id == par.ParSetID){
                            if (paraset.size == 0){
                                paraset = ",".join(par.ID:string, par.value:string);
                            } else{
                                paraset = ",".join(paraset, par.ID:string, par.value:string);
                            }
                        }
                    }
                    var counter = 0;
                    for archive in EpsilonArchivee{
                        if (id == archive.ParsetID){
                            if (counter < numvar.size){
                                if (archvar.size == 0){
                                    archvar= ",".join(archive.variablename[counter], archive.variableFtotal[counter]:string);
                                } else {
                                    archvar= ",".join(archvar, archive.variablename[counter], archive.variableFtotal[counter]:string);
                                }
                                counter = counter +1;
                                
                            }
                            var sizeind = archive.IndicatorName.size -1;
                            for j in 0..sizeind{
                                if (archInd.size == 0){
                                    archInd= ",".join(archive.IndicatorName[j], archive.IndicatorValue[j]: string);
                                } else {
                                    archInd= ",".join(archInd, archive.IndicatorName[j], archive.IndicatorValue[j]: string);
                                }
                            }
                        }
                    }
                    ParsetString.append(paraset);
                    ArchiveString.append(":".join(archvar, archInd));
                }
                var stringF: string = ParsetString[0];
                var n = ParsetString.size -1;
                var stringS: string = ArchiveString[0];
                for i in 1..n{
                    stringF = "|".join(stringF, ParsetString[i]);
                    stringS = "|".join(stringS, ArchiveString[i]);
                }
                var Arch_Input = " ".join(Arch_Command, multitype, stringS , stringF, boundcheck:string, hostidcomputersharedthis:string, "--project", EFProjectPath);

            }
            if (multitype =="Multi-VarIndicator"){
                
                var objectivenames = getMultiObjectiveNames();
                objectivenames.remove(objectivenames.getValue(0));
                for id in IDs {
                    var paraset: string;  
                    var archInd: string; 
                    var archvar: string; 
                    for par in EpsilonParsett{
                        if (id == par.ParSetID){
                            if (paraset.size == 0){
                                paraset = ",".join(par.ID:string, par.value:string);
                            } else{
                                paraset = ",".join(paraset, par.ID:string, par.value:string);
                            }
                        }
                    }
                    var counter = 0: int;
                    for archive in EpsilonArchivee{
                        if (id == archive.ParsetID){
                            var variablename = archive.variablename;
                            if (counter < numvar.size){
                                if (archvar.size == 0){
                                    archvar= ",".join(variablename[counter], archive.variableFtotal.getValue(counter):string);
                                } else {
                                    archvar= ",".join(archvar, variablename[counter], archive.variableFtotal.getValue(counter):string);
                                }
                                
                                var templist: list(string);
                                for x in objectivenames[(2*counter)+1].split(":"){
                                    templist.append(x);
                                }
                                var sizeind = templist.getValue(1):int;
                                for j in 0..sizeind{
                                    if (archInd.size == 0){
                                        archInd= "/".join(variablename[counter], archive.IndicatorName[j]);
                                        archInd = ",".join(archInd, archive.IndicatorValue[j]: string);
                                    } else {
                                        var tempvar = "/".join(variablename[counter], archive.IndicatorName[j]);
                                        archInd = ",".join(archInd, tempvar, archive.IndicatorValue[j]: string);
                                    }
                                }
                                counter=(counter +1);
                            }
                            
                        }
                    }
                    ParsetString.append(paraset);
                    ArchiveString.append(":".join(archInd, archvar));
                }
                var stringF: string = ParsetString[0];
                var n = ParsetString.size -1;
                var stringS: string = ArchiveString[0];
                for i in 1..n{
                    stringF = "|".join(stringF, ParsetString[i]);
                    stringS = "|".join(stringS, ArchiveString[i]);
                }
                var Arch_Input = " ".join(Arch_Command, multitype, stringS , stringF, boundcheck:string, hostidcomputersharedthis:string, "--project", EFProjectPath);

            }
            var Arch = spawnshell(Arch_Input, stdout=PIPE);
            var line: string;
            var SimIDCurrent: string;
            while Arch.stdout.readline(line) {
                SimIDCurrent = line;
            }
            Arch.wait();
        
        } else {
            writeln("Error: WriteEpsilonExchangeData Failed! on Locale %s", here.hostname);
        }
        return SimIDCurrent;
        
    }

    /*--------------------------------Island-based Architecture --> Read Exchange Info for Multi-Objective Calibration ----------- 
    Usage: This function takes a list of record nondominatedArchiveElement, then reads them and 1- Check Dominance of them and adds the non dominated ones to its Best Archiev table
    Input: A list of nondominatedArchiveElement records, Multiobjective Type,  and the size of the archive for Bounded archives 
    Output: A list of nondominatedArchiveElement records 
    Where this Function is used:  At the Identified simulation numbers where the exchange info should take place --> On all Islands 
    C# functions: It works with "readExchangeArchive" Function,
    It works with the BestParameterSet_Archive Table.
    */
    proc readExchangeArchive(ArchiveList: list(nondominatedArchiveElement), MultiobjType: string, boundcheck: bool){
        
        var datatobesent: string = "start";
        for item in ArchiveList{
            var SimID = item.getSimulationID(): string;
            var variablename = item.getVariable_Name();
            var TotalF = item.getTotalFValue(): string;
            var indicatorName = item.getIndicator_Name();
            var indicatorValue = item.getIndicator_Value();
            var n = indicatorName.size - 1;
            for i in 0..n {
                var line = ",".join(SimID, variablename, TotalF, indicatorName[i], indicatorValue[i]:string);
                datatobesent = ",".join(datatobesent, line);
            }
        }
        var FBest_Command = "dotnet run readExchangeArchive";
        var FBest_Input = " ".join(FBest_Command, datatobesent, MultiobjType, boundcheck:string, "--project", EFProjectPath);
        var FBest = spawnshell(FBest_Input, stdout=PIPE);
        var line: string;
        while FBest.stdout.readline(line) {
            if (line.isEmpty() == true){
                break;
            } else {
                writeln("There is a problem with Reading Exchange data on Locale %s", here.hostname);
            }
        }
        FBest.wait();
    }


    /* -------------------------Single-Objective-------------------------------------- */

    /*
    Usage:when we are running Single-objective, sometimes the Total F is not the Objective Function and we need to indicate which indicator is the 
    Objective --> By this function in Sinhel-objective calibration we an get eth Indicator Value to set it to Best F for the optimization Algorithm 
    Input: It gets a Performance row to get the Indicator value --> In fact this Function is Run on the Worker node for the Functional Str 
    Output: The indicator value 
    Where this Function is used: For the Functional Strategy,
    C# functions: NONE
    */
   

    /* -------------------------Getters and Setters --------------------------------------*/

    proc setParallelizationStrategy(value:string){
        this.Parallelization_Strategy = value;
    }
    proc getParallelizationStrategy(){
        return this.Parallelization_Strategy;
    }
    proc setMeasureScope(value:string){
        this.MeasureScope = value;
    }
    proc getMeasureScope(){
        return this.MeasureScope;
    }
    proc setBestF(value: real){
        this.BestF = value;
    }
    proc getBestParArchive(){
        return this.BestParArchive;
    }
    proc setBestParArchive(value: list(shared Parameter, parSafe=true)){
        this.BestParArchive = value;
    }
    proc getBestF(){
        return this.BestF;
    }
    proc setcurentSimID(value: string){
        this.curentParsetID = value;
    }
    proc getcurentSimID(){
        return this.curentParsetID;
    }
    proc setStopAlgorithm(value: int){
        this.StopAlgorithm = value;
    }
    proc getStopAlgorithm(){
        return this.StopAlgorithm;
    }
    proc setSRCCFrequency(value:real){
        this.SRCCFrequency = value;
    }
    proc getSRCCFrequency(){
        return this.SRCCFrequency;
    }
    proc setCalibrationType(value:string){
        this.Calibration_Type = value;
    }
    proc getCalibrationType(){
        return this.Calibration_Type;
    }
    proc setCalibrationAlgorithm(value:string){
        this.Calibration_Algorithm_Name = value;
    }
    proc getMasterBestParsets(){
        return this.MasterBestParsets;
    }
    proc setMasterBestParsets(value: list(list(shared Parameter, parSafe=true))){
        this.MasterBestParsets = value;
    }
    proc getMasterBestParsetsSingle(){
        return this.MasterBestParsetsSingle;
    }
    proc setMasterBestParsetsSingle(value: list(shared Parameter, parSafe=true)){
        this.MasterBestParsetsSingle = value;
    }
    proc getCalibrationAlgorithm(){
        return this.Calibration_Algorithm_Name;
    }
    proc setMultiObjType(value:string){
        this.MultiObjType = value;
    }
    proc getMultiObjType(){
        return this.MultiObjType;
    }
    proc setDoInfoExchange(value:string){
        this.DoInfoExchange = value;
    }
    proc getDoInfoExchange(){
        return this.DoInfoExchange;
    }
    proc setStoppingCriteria(value:string){
        this.Stopping_Criteria = value;
    }
    proc getStoppingCriteria(){
        return this.Stopping_Criteria;
    }
    proc setExchangeFrequency(value:real){
        this.Exchange_Frequency = value;
    }
    proc getExchangeFrequency(){
        return this.Exchange_Frequency;
    }
    proc setNumFArchivesExchange(value:real){
        this.Number_FArchives_Exchange = value;
    }
    proc getNumFArchivesExchange(){
        return this.Number_FArchives_Exchange;
    }
    proc setStoppingValue(value:real){
        this.Stopping_Value = value;
    }
    proc getStoppingValue(){
        return this.Stopping_Value;
    }
    proc setNumAllowedInArchive(value:real){
        this.Num_Allowed_In_Archive = value;
    }
    proc getNumAllowedInArchive(){
        return this.Num_Allowed_In_Archive;
    }
    proc setBoundArchive(value:string){
        this.Bound_Archive = value;
    }
    proc setLastDoneSimID(value:string){
        this.LastSimID = value;
    }
    proc getLastDoneSimID(){
        return this.LastSimID;
    }
    proc getBoundArchive(){
        return this.Bound_Archive;
    }
    proc setStoppingMDR(value: real){
        this.StoppingMDR = value;
    }
    proc getStoppingMDR(){
        return this.StoppingMDR;
    }
    proc setTotalF(value: list(string)){
        this.TotalF = value;
    }
    proc getTotalF(){
        return this.TotalF;
    }
    proc getLocalFValue(value: bool){
        this.LocalFValue = value;
    }
    proc setLocalPerformanceString(value: string){
        this.LocalPerformanceString = value;
    }
    proc getLocalPerformanceString(){
        return this.LocalPerformanceString;
    }
    proc setDominanceStatus(value: string){
        this.Dominance = value;
    }
    proc getDominanceStatus(){
        return this.Dominance;
    }
    proc setParsetList(value: list(EpsilonParset)){
        this.ParsetList = value;
    }
    proc getParsetList(){
        return this.ParsetList;
    }
    proc setArchivesList(value: list(EpsilonArchive)){
        this.ArchivesList = value;
    }
    proc getArchivesList(){
        return this.ArchivesList;
    }
    proc setSimulationIDU(value:string){
        this.SimulationIDU = value;
    }
    proc getSimulationIDU(){
        return this.SimulationIDU;
    }
}