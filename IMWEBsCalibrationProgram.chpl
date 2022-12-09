/* Constants I have used
1- Parallelization Strategy --> 1- Functional 2- Dependent-Multi-Search and 3- Hybrid 
2- Calibration Types --> 1- Single-Objective 2- Multi-Objective 
3- Calibration Algorithms 1- DDS 2- SRCC-DDS 3-PADDS 4- SRCC-PADDS
4- MeasureScope  --> 1- Speed and 2- Convergence
*/

/* Documentation -->
    1- For Functional Parallelization --> I start with one Parameter set, which is Random, and then I will send this Parameter set to all the Machines. 
    Then, they update the parameter set and calculate the performance values for the parameter set and FBests, and they return it to the Master. 
*/

/* author: Marjan Asgari 
Fall 2021 */

use List;
use Random;
use IO;
use FileSystem;
use Spawn;
use runIMWEBs;
use ConfigMethods;
use ProgramDatabase;
use ParameterSet;
use Records;
use Path;
use Math;
use DateTime;
use ManualTablesFill;


class IMWEBsCalibrationProgram{

    /* The following variables should be defined before running the program:
        1- We should define a total simulation number that we want to run for our program
        2- We need to define the number of simulations that should be allocated to each machine at each data transfer.  
    */
    var EntireSimulationNumbers: int = 50 ; /* The entire number of simulations that you want to run for the project */
    var ProjectPath: string; /* This the EF core Project Path */
    var HDF5Path: string; /* This is the path where HDF5 libs are stored on Worker Machines; Without knowing this path, IMWEBs model can't be run */
    var IMWEBsbashfilePath: string; /* IMWEBs should get run in a bash file, since before it we have to set some compiler's variables. Thus, we need a bash file which opens a bash shell, sets the variables, and runs the IMWEBs */
    var IMWEBsModelPath: string;
    var IMWEBsProjectPath: string;
    var CSVFilesPath: string;
    var CurSimIDMaster: string;
    var CurParSetMaster: list(shared Parameter, parSafe=true);
    var ClusterArchitecture = "Multi-Computer";
    var BeginPADDSVar: string = "NONE";
    var BeginPADSSFBest: real = 999;
    //var ProjectName = "PADDSMultiObjective"; /* The project name we want to carry out the calibration for --> This name will be on the Base_project Table */
    var ProjectName = "DDSSingleObjective"; /* The project name we want to carry out the calibration for --> This name will be on the Base_project Table */
    
    
    proc init(ProPath:string, HDF5:string, IMWEBsBashfile: string, Modelpath: string, ModelProjectPath: string, csv:string){
        this.ProjectPath = ProPath;
        this.HDF5Path = HDF5;
        this.IMWEBsbashfilePath = IMWEBsBashfile;
        this.IMWEBsModelPath = Modelpath;
        this.IMWEBsProjectPath = ModelProjectPath;
        this.CSVFilesPath = csv;
    }
    proc RunAutoCalibration{

        writeln("----------------------------------------------------------------------------------------------------\n");
        writeln("Database Update is Beginning on ALL Worker Nodes of our Computer Cluster\n");
        writeln("----------------------------------------------------------------------------------------------------\n");
        writef("-------------------Database Update's Start Date-Time is: %s -------------------------------------\n", datetime.today():string);
        writeln("----------------------------------------------------------------------------------------------------\n");

        /* Multi-objective */
        //var manualclass = new ManualTablesFill("Functional", "Multi-Objective", ProjectName, "Multi-Variable", "PADDS", "Convergence", "FV-STD", EntireSimulationNumbers:string, "0", EntireSimulationNumbers, ProjectPath, IMWEBsModelPath, IMWEBsProjectPath, 2, CSVFilesPath);
       //manualclass.FillTables();

        /* Single-objective */

        var manualclass = new ManualTablesFill("Functional", "Single-Objective", ProjectName, "NONE", "SRCC-DDS", "Convergence", "NumberofSimulations", EntireSimulationNumbers:string, "0", EntireSimulationNumbers, ProjectPath, IMWEBsModelPath, IMWEBsProjectPath, 2, CSVFilesPath);
        manualclass.FillTables(); 

        writeln("Database Update Successfully Finished on ALL Worker Nodes of our Computer Cluster\n");
        writeln("----------------------------------------------------------------------------------------------------\n");
        writef("Database Update's Start End Date-Time is: %s \n", datetime.today():string);
        writeln("----------------------------------------------------------------------------------------------------\n");
        


                                                /*----------Only Single Objective Calibration--------------*/

        var SingleObjIndicatorName = "TotalF"; /* If you are working with SingleObjective calibration and you are interested in any indicator rather than TotalFvalue, 
        define objective's name here.
        e.g.,  R2, RMSE ==> Otherwise, set this variable to  "TotalF" 
        */

                                                /*----------Only Multi Objective Calibration--------------*/
        var StoppingCriterion: string; /* With which method, the stopping criterion should be updated --> 
                                        It can be 1-MDR 2- FV-STD 3- CD-STD */
        var GDThreshold: real; /* The max acceptable closeness to the Pareto Front, if we have a Pareto Front for the problem at hand */

                                                /*----------Only Dependent Search --------------*/
        var IslandInitialTotalSimulations: int; /* How many Simulations Should be allocated to each island?  */
        var ParetoFrontMaster: bool = false; /* Do we have a Reference Pareto Front? If yes, set it true, otherwise --> false */
        var ExchageArchiveMethod: string; /* With what method, the exchanged Archive Elements should be selected  --> 
                                           It can be 1- EpsilonIndicator, 2-ScottSpacing, and 3-ObjectiveWeights  */
        var IslandsDBCopyPath: string; /* The path on the Coordinator Machine that All Islands' DBs should get copied at the End */

        /* ----------------Now we need to read the required information for the database and assign them to variables ---------------- */
        var PrDB = new ProgramDatabase(ProjectPath, ProjectName);
        PrDB.getOptimizationInfo();
        writeln("-----------------------Parallel Calibration of IMWEBs Hydrologic Model------------------------------\n");
        writeln("----------------------------------------------------------------------------------------------------\n");
        writeln("-------------------Reading the General Information of the Optimization Project ---------------------\n");
        var CalibrationType: string = PrDB.getCalibrationType(); /* whether it is single-objective or multi-objective */
        writef("Calibration Type is %s. Running on the Master/Controller Node:  %s\n",CalibrationType, here.hostname);
        writeln("----------------------------------------------------------------------------------------------------\n");
        var MultiobjectiveType = PrDB.getMultiObjType(); /* whether it is 1- Multi-indicator, 2- Multi-variable and 3- Multi-VarIndicator */
        writef("Multiobjective Type is %s. Running on the Master/Controller Node: %s\n", MultiobjectiveType, here.hostname);
        writeln("----------------------------------------------------------------------------------------------------\n");
        var ParallelizationStrategy = PrDB.getParallelizationStrategy(); /* whether it is Functional, Dependent multi-search or Hybrid */ 
        writef("Parallelization Strategy is %s. Running on the Master/Controller Node: %s\n", ParallelizationStrategy, here.hostname);
        writeln("----------------------------------------------------------------------------------------------------\n");
        var CalibrationAlgorithm = PrDB.getCalibrationAlgorithm(); /* whether it is DDS, SRCC-DDS, PADDS, or SRCC-PADDS */
        writef("Calibration Algorithm is %s. Running on the Master/Controller Node: %s\n", CalibrationAlgorithm, here.hostname);
        StoppingCriterion = PrDB.getStoppingCriteria(); 
        writeln("----------------------------------------------------------------------------------------------------\n");
        writef("Stopping Criterion is %s. Running on the Master/Controller Node: %s\n", StoppingCriterion, here.hostname);
        writeln("----------------------------------------------------------------------------------------------------\n");
        var DesiredObjectiveValue = PrDB.getStoppingValue():real; /* At what objective function value should we stop? */
        writef("Desired Objective Value is %s. Running on the Master/Controller Node: %s\n", DesiredObjectiveValue:string, here.hostname);
        writeln("----------------------------------------------------------------------------------------------------\n");
        var ExchangeFrequency = PrDB.getExchangeFrequency(); /* How frequent the information should get exchanged --> In terms of number of simulations */ 
        writef("Exchange Frequency is %s. Running on the Master/Controller Node: %s\n",ExchangeFrequency:string, here.hostname);
        writeln("----------------------------------------------------------------------------------------------------\n");
        var NumFArchivesExchange = PrDB.getNumFArchivesExchange(); /* How many Non dominated solutions in the "exchanged" archive should be*/
        writef("Number of Archive Elements to be Exchanged is %s. Running on the Master/Controller Node: %s\n", NumFArchivesExchange:string, here.hostname);
        writeln("----------------------------------------------------------------------------------------------------\n");
        var NumAllowedInArchive = PrDB.getNumAllowedInArchive(); /* If we have a bounded archive, how many non-dominated solutions should it store? What is the max value? */ 
        writef("Number of Archive Elements to be in the Archive is %s. Running on the Master/Controller Node: %s\n", NumAllowedInArchive:string, here.hostname);
        writeln("----------------------------------------------------------------------------------------------------\n");
        var BoundArchive = PrDB.getBoundArchive(); /* Whether we have a bounded or unbounded archive? */
        writef("Bounding Archive is %s. Running on the Master/Controller Node: %s\n",BoundArchive:string, here.hostname);
        writeln("----------------------------------------------------------------------------------------------------\n");
        var SRCCFreq = PrDB.getSRCCFrequency(); /* After how many simulations the worker nodes should send their results to the manager node? */
        writef("SRCC Results are Sent Every %s Simulations. Running on the Master/Controller Node: %s\n",SRCCFreq:string, here.hostname);
        writeln("----------------------------------------------------------------------------------------------------\n");
        var MeasureScope = PrDB.getMeasureScope(); /* What is the Measure Scop? Speed or Convergence? */
        writef("Measure Scope is  %s. Running on the Master/Controller Node: %s\n",MeasureScope, here.hostname);
        writeln("----------------------------------------------------------------------------------------------------\n");

        /*-------------------------------------- This variable is going to be filled at the end of the works on all machines, on the Master Node ------------------- */
        var CalibrationSpeed: real; 
        var MasterVariablesNames: list(string); // For storing Model Variables' names which we want to calibrate 
        var MasterIndicatorNames: list(list(string)); // For storing a list of indicator names for each variable, if we have Multi-VArIndicator Calibration type 
        var MasterObjectives: list(string); // For storing "objective names" if we have Multi-variable or multi-indicator calibration Type  

        /* These are locks */
        var MasterTablesAvailable$: sync int = 1;
        var SimuID$: sync int = 1;
        

        /* -------------------------------------Functional Strategy -------------------------------- */
        if (ParallelizationStrategy == "Functional") {
            /* The idea is that with using the Functional Parallelization Strategy, Workers nodes only run the IMWEBs model and return "Performance Results" to the Master Node.
            Then, the master node starts updating tables on its side. Thus, the following record is for storing Performance results */
            var ArchiveStatsList: list(real); // For STD Stopping criterion for Multi-objective Calibration
            var ArchiveStatsListFVS: list(list(string)); // For FVS Stopping criterion for Multi-objective Calibration
            var StoppingCriterionList: list(real); // For MRD Stopping criterion
            /* I can detect the failure of the machine in three spots --> In two catch blocks and 2- when the IMWEBs Success is False
            in those spots, I fill the following list */

            var MyRemoteLocales: [0..numLocales-2] locale = for i in 1..numLocales-1 do Locales[i];
            class IamFailed {
                var HostID: int;
                var SimID: list(string);
                var ParID: list(string);
                var Numfailed: int;

                proc iniit(id:int, simid:string, parid:string, numfailed:int){
                    this.HostID = id;
                    this.SimID= simid;
                    this.ParID = parid;
                    this.Numfailed = numfailed;
                }
            }
            var readFaildList$: sync bool = true;
            /* The following Lists are filled as the Worker Nodes start to operate. When their size reaches the number of locales, the Update Computers and CPU function will be called to update these two tables on the 
            Master Node */ 
            class ComputerCPUtablesUpdate{
                var StartSimIDs: string;
                var TotalSimIDs: int;
                var UpdateComHostIDs: int;
                var UpdateComHostNames: string;

                proc init(Sim:string, Total:int, hostid:int, hostname:string){
                    this.StartSimIDs = Sim;
                    this.TotalSimIDs = Total;
                    this.UpdateComHostIDs = hostid;
                    this.UpdateComHostNames = hostname;
                }
            }
            // Do it for multi as well 
            class NodeHasFinished{
                var ReadytoCease$: sync bool;
                var HostName: string;

                proc init(host:string){
                    this.HostName = host;
                }
                proc ChangeStatus(status:bool){
                    this.ReadytoCease$.writeEF(status);
                }
                proc readCeaseVar(){
                    return this.ReadytoCease$.readFE();
                }
            }
            record RowsForMasterTablesFunctionalSingle{
                var SimID: string;
                var ParsetId: string;
                var ParmeterSet: shared ParameterSetInitialization = new ParameterSetInitialization(ProjectPath);
                var PerformanceResult: list(list(string));
                var IMWEBsEndTimeDate: string;
                var IMWEBsStartTimeDate: string;
                var IMWEBsSimulationRunTime: string;
            }
            record RowsForMasterTablesFunctionalMulti{ 
                var SimID: string;
                var TotalF: real;
                var ParsetId: string;
                var ParmeterSet: shared ParameterSetInitialization = new ParameterSetInitialization(ProjectPath);
                var PerformanceResult: list(list(string));
                var VariableName: string;
                var IndicatorName: list(string);
                var IMWEBsEndTimeDate: string;
                var IMWEBsStartTimeDate: string;
                var IMWEBsSimulationRunTime: string;
            }
            /* The following records are for tracking Worker Machines On our cluster  */ 
            class AvailableMachinesFunctionalStrSingle{
                var hostID: int;
                var hostName: string;
                var NumCores: int;
                var Fbest: real;
                var BestParSet: list(shared Parameter, parSafe=true);
                var FbestArchive: real;
                var BestParSetArchive: list(shared Parameter, parSafe=true);
                var statusFinished: bool;
                var SRCCStableResults: list(shared ParametersSRCCValues);
                var WriteToMasterTables$: sync bool; /* This variable is Sync Variable since it should get locked when we are reading its data and deleting the rows which has been added to the tables, 
                this lock lets us not delete any information that has been added to this variable after reading data from it and before emptying this variable */
                var DataforMasterTables: list(RowsForMasterTablesFunctionalSingle);
                
                proc init(id:int, name:string, cores: int){
                    this.hostID = id;
                    this.hostName = name;
                    this.NumCores = cores;
                    this.Fbest = 999;
                    this.BestParSet = new list(shared Parameter, parSafe=true);
                    this.FbestArchive = 999;
                    this.BestParSetArchive = new list(shared Parameter, parSafe=true);
                    this.statusFinished = false;
                    this.SRCCStableResults = new list(shared ParametersSRCCValues);
                    this.WriteToMasterTables$ = true;
                    this.DataforMasterTables = new list(RowsForMasterTablesFunctionalSingle);
                } 
                proc SetSRCCvalues(values: list(shared ParametersSRCCValues )){
                    this.SRCCStableResults = values;
                }
            }
            class AvailableMachinesFunctionalStrMulti{
                var hostID: int;
                var hostName: string;
                var NumCores: real;
                var Fbest: real;
                var UpdatedStopingCriterionValue: real;
                var DDSVariableName: string;
                var RepeatVariable: string = "";
                var RepeatIndicator: list(string);
                var DDSIndicatorName: list(string);
                var objectivesDone: real; //if equal to the Numobjectives --> Crowding distance 
                var NumberofObjectives: real;
                var crowdingDistanceParSet: list(shared Parameter, parSafe=true);
                var CurrentParameterSet: list(shared Parameter, parSafe=true);
                var CurrentArchive: list(string);
                var statusFinished: bool;
                var ArchiveFBest: real;
                var BestParSetArchive: list(shared Parameter, parSafe=true);
                var SRCCStableResults: list(shared ParametersSRCCValues);
                var MasterArchive: list(string);
                var WriteToMasterTables$: sync bool; /* This variable is Sync Variable since it should get locked when we are reading its data and deleting the rows which has been added to the tables, 
                this lock lets us not delete any information that has been added to this variable after reading data from it and before emptying this variable */
                var DataforMasterTables: list(RowsForMasterTablesFunctionalMulti); 
            
                proc init(id:int, name:string, cores: int){
                    this.hostID = id;
                    this.hostName = name;
                    this.NumCores = cores;
                    this.Fbest = 999;
                    this.UpdatedStopingCriterionValue = 0;
                    this.DDSVariableName = "NOTSET";
                    this.DDSIndicatorName = new list(string);
                    this.objectivesDone = 0;
                    this.NumberofObjectives = 0;
                    this.crowdingDistanceParSet = new list(shared Parameter, parSafe=true);
                    this.CurrentParameterSet = new list(shared Parameter, parSafe=true);
                    this.CurrentArchive = new list(string);
                    this.statusFinished = false;
                    this.BestParSetArchive = new list(shared Parameter, parSafe=true);
                    this.MasterArchive = new list(string);
                    this.WriteToMasterTables$ = true;
                    this.DataforMasterTables = new list(RowsForMasterTablesFunctionalMulti);
                }
                proc SetSRCCvalues(values: list(shared ParametersSRCCValues)){
                    this.SRCCStableResults = values;
                }
                proc setRepeatVariable(value:string){
                    this.RepeatVariable = value;
                }
                proc setArchiveFBest(valuee:real){
                    this.ArchiveFBest = valuee;
                }
                proc setRepeatVariableIndicatorandFBest(value:string, valueee:string){
                    this.RepeatVariable = value;
                    this.RepeatIndicator.append(valueee);
                }
            }
            /* Now we are creating Lists of Machines */
            var MachinesSingle: list(shared AvailableMachinesFunctionalStrSingle);
            var MachinesMulti: list(shared AvailableMachinesFunctionalStrMulti);
            var ComCpuInfo: list(shared ComputerCPUtablesUpdate);
            var IamFailedList : list(shared IamFailed);
            var FinalStatus: list(shared NodeHasFinished);

            /* This Function updates both Computers Info and CPU info tables */
            var UpdateComputers$: sync bool = true;
            proc updateComputerInfos(){ 
        
                var StartSimIDs: list(string);
                var TotalSimIDs: list(int);
                var UpdateComHostIDs: list(int);
                var UpdateComHostNames: list(string);
            
                for info in ComCpuInfo{
                    StartSimIDs.append(info.StartSimIDs);
                    TotalSimIDs.append(info.TotalSimIDs);
                    UpdateComHostIDs.append(info.UpdateComHostIDs);
                    UpdateComHostNames.append(info.UpdateComHostNames);
                }
                PrDB.ComputersInfoUpdate(StartSimIDs, TotalSimIDs, ClusterArchitecture, "Functional", UpdateComHostIDs, UpdateComHostNames);
                if (MachinesMulti.size == 0){
                    for M in MachinesSingle{
                        PrDB.CPUInfoUpdate(M.hostName, M.NumCores);
                    }
                } else if (MachinesSingle.size == 0){
                    for M in MachinesMulti{
                        PrDB.CPUInfoUpdate(M.hostName, M.NumCores);
                    }
                }
            }
            if (CalibrationType == "Single-Objective"){
                for loc in 0..MyRemoteLocales.size-1 do {
                    on MyRemoteLocales[loc] do {
                        var NewMachine = new shared AvailableMachinesFunctionalStrSingle(here.id, here.hostname,here.numPUs());
                        if (here.numPUs() != 0){
                            MachinesSingle.append(NewMachine);
                        }
                        var NewCominfo = new shared ComputerCPUtablesUpdate(0:string, 0, here.id, here.hostname);
                        var StatusInit = new shared NodeHasFinished(here.hostname);
                        var FaildlistforMachines = new shared IamFailed(here.id, new list(string), new list(string),0);
                        ComCpuInfo.append(NewCominfo);
                        FinalStatus.append(StatusInit);
                        IamFailedList.append(FaildlistforMachines);
                    }
                }
                setInitialParameterSetFunctional(); // This sets a random ParameterSet as the Initial ParameterSet to all the machines
                
            }
            if (CalibrationType == "Multi-Objective"){
                var DBClass = new ProgramDatabase(ProjectPath, ProjectName);
                for loc in 0..MyRemoteLocales.size-1 do{
                    on MyRemoteLocales[loc] do{
                        var NewMachine = new shared AvailableMachinesFunctionalStrMulti(here.id, here.hostname,here.numPUs());
                        if (here.numPUs() != 0){
                            MachinesMulti.append(NewMachine);
                        }
                        var NewCominfo = new shared ComputerCPUtablesUpdate(0:string, 0, here.id, here.hostname);
                        var StatusInit = new shared NodeHasFinished(here.hostname);
                        var FaildlistforMachines = new shared IamFailed(here.id, new list(string), new list(string),0);
                        ComCpuInfo.append(NewCominfo);
                        FinalStatus.append(StatusInit);
                        IamFailedList.append(FaildlistforMachines);
                    }
                }
                setInitialParameterSetFunctional();

                /* The point of this Block of code is the fact that we need to know exactly 1- What are the model variables we have 2- what are the indicators that we have for each model variable. 
                This information is required for the beginning of the PADDS algorithm since it should optimize each of these objectives as its first steps. 
                So, we create Variables, Indications and ObjectiveNames variables and we call them on Worker Machines.  */ 

                /* Objective Names List is a list with 1- The first element is the calibration type 2- the second element is the First Variable name with the number of variables we have  
                3- the third one is the first indicator name with the number of indicators for the first variable and etc */
                var ObjectiveNames = PrDB.getMultiObjectiveNames();
                if (ObjectiveNames[0].startsWith("Multi-Variable") ==  true || ObjectiveNames[0].startsWith("Multi-Indicator") == true){
                    ObjectiveNames.pop(0);
                    for Machine in MachinesMulti{
                        Machine.NumberofObjectives = ObjectiveNames.size;
                    }
                    MasterObjectives = ObjectiveNames;

                } else {
                    var vars: list(string);
                    for i in ObjectiveNames[0].split(":"){
                        vars.append(i);
                    }
                    var numVar = vars.getValue[1]:int;
                    var count: int = 0; 
                    var Numobj: real; 
                    for i in 1..numVar{
                        var indics: list(string);
                        var counter = i + count;
                        MasterVariablesNames.append(ObjectiveNames[counter]); // Filling in the Variables List
                        for k in ObjectiveNames[counter+1].split(":"){
                            indics.append(k);
                        }
                        var indicNum = indics[1]: int; // Getting the Number of objectives the current variable has 
                        var indic: list(string);
                        for j in 1..indicNum{
                            var temp: list(string);
                            for h in ObjectiveNames[counter+j].split(":"){
                                temp.append(h);
                            }
                            indic.append(temp[0]); // Creating a list of indicators for the current variable 
                            Numobj = Numobj + 1; // Summing the number of objectives 
                            count = count + 1;
                        }
                        MasterIndicatorNames.append(indic); // Appending the Indicator List for the current variable to the Indicators List 
                    }
                    for Machine in MachinesMulti{
                        Machine.NumberofObjectives = Numobj; // Adding the Number of objectives for the current Machine 
                    }
                    /* Check the correctness */
                    var ConsoleStringvariables: string;
                    for Vari in MasterVariablesNames{
                        ConsoleStringvariables = "/".join(ConsoleStringvariables, Vari);
                    }
                    writeln(ConsoleStringvariables);
                    var ConsoleStringindicators: string;
                    for Indi in MasterIndicatorNames{
                        var TempString: string;
                        for varIndis in Indi{
                            TempString = ",".join(TempString, varIndis);
                        }
                        ConsoleStringindicators = "/".join(ConsoleStringindicators, TempString);
                    }
                    writeln(ConsoleStringindicators);
                }
            }
            /* This is For Single Objective Calibration */
            proc FillMasterTablesSingleObjectiveSingle(CheckSRCCValues: bool){
                
                writeln("****************************************************************************************************\n");
                writeln("------------------------------------Updating Master Tables------------------------------------------\n");
                var lock = MasterTablesAvailable$.readFE(); /* We set a lock when this function starts operating, since we do not want multiple worker machines call this function and concurrency issue happens. 
                So, a worker machine calls this fucntion and locks it, other machiens, whe ncall it, tehy see teh lock and teh break the call. */
                record InsertData{
                    var hostname: string;
                    var hostID: int;
                    var PureData: list(RowsForMasterTablesFunctionalSingle);
                    var FBest: real;

                    proc init(host:string, id:int, Data:list(RowsForMasterTablesFunctionalSingle), Fbest:real){
                        this.hostname = host;
                        this.hostID = id;
                        this.PureData = Data;
                        this.FBest = Fbest;
                    }
                }
                var AllInsertData: list(InsertData);
                for M in MachinesSingle{
                    if (M.DataforMasterTables.size != 0) { // If the machine has shared its results
                        var readvalue = M.WriteToMasterTables$.readFE(); // Set the lock, since we do not want to lose data
                        var Mdata = new InsertData(M.hostName, M.hostID, M.DataforMasterTables, M.Fbest);
                        M.DataforMasterTables.clear();
                        M.WriteToMasterTables$.writeEF(true); // Unlock
                        AllInsertData.append(Mdata);
                    }
                }
                for InsertRow in AllInsertData{
                    var hostname = InsertRow.hostname;
                    var hostid = InsertRow.hostID;
                    
                    for Indiv in InsertRow.PureData{
                        var varname: list(string);
                        var IndicName: list(string);
                        var Indicvalue: list(string);
                        var WIndicvalue: list(string);
                        for row in Indiv.PerformanceResult{
                            varname.append(row[0]);
                            IndicName.append(row[3]);
                            Indicvalue.append(row[5]);
                            WIndicvalue.append(row[4]);
                        }

                        var ProgramDB = new ProgramDatabase(ProjectPath, ProjectName, InsertRow.hostname, InsertRow.hostID);
                        ProgramDB.UpdateMasterTablesFunctional(hostname, ProjectName, Indiv.SimID, Indiv.ParsetId, Indiv.IMWEBsEndTimeDate, Indiv.IMWEBsStartTimeDate, Indiv.IMWEBsSimulationRunTime:real, Indiv.ParmeterSet.getParameterSet(), varname, IndicName, Indicvalue, WIndicvalue);
                        var VarNa:string;
                        var IndicNa:string;
                        ProgramDB.Archive_Update(Indiv.ParmeterSet, InsertRow.FBest, VarNa, IndicNa, false);
                        /* The FValue that the the Archive Fuction returns is TotalF if you want to change it, change it in c# */
                        writef("--------------------------------Found Archive FVlaue is %s\n", ProgramDB.getBestF());
                        writef("--------------------------------Update News: Global Fvalue based on the Master Archive is %s for Machine %s Info\n", (ProgramDB.getBestF()):string, hostname);
                        writeln("--------------------------------\n");
                        for MA in MachinesSingle{
                            MA.FbestArchive = ProgramDB.getBestF();
                            MA.BestParSetArchive = ProgramDB.getBestParArchive();
                        }
                        if (CheckSRCCValues == true){
                            var SRCCobject = new ParametersetUpdate(ProjectPath);
                            var SRCCValues: list(shared ParametersSRCCValues);
                            writeln("--------------------------------Calculating SRCC Values is taking place!\n");
                            writeln("--------------------------------\n");
                            SRCCValues = SRCCobject.SRCCStableValue(Indiv.SimID, ProjectName, SingleObjIndicatorName);
                            if (SRCCValues.size != 0){
                                writeln("--------------------------------Stable SRCC Values have been Achieved!\n");
                                writeln("--------------------------------\n");
                                var SRCCString: string; 
                                for M in SRCCValues{
                                    if (SRCCString.size == 0){
                                        var LocalString = M.ParameterCalibrationID:string;
                                        LocalString = ":".join(LocalString, M.SRCCValue:string);
                                        SRCCString = LocalString;
                                    } else {
                                        var LocalString = M.ParameterCalibrationID:string;
                                        LocalString = ":".join(LocalString, M.SRCCValue:string);
                                        SRCCString = "--".join(SRCCString, LocalString);
                                    }
                                }
                                writef("--------------------------------Stable SRCC Values are %s\n", SRCCString);
                                writeln("--------------------------------\n");
                                for machine in MachinesMulti{
                                    machine.SetSRCCvalues(SRCCValues);
                                }
                            } else {
                                var STDVALS= SRCCobject.getSTDValues();
                                if (STDVALS.size == 0){
                                    writeln("--------------------------------Calculation of SRCC Values' Standard Deviation is Not Started Yet (Not Enough Simulations have been done)\n");
                                    writeln("--------------------------------\n");
                                } else {
                                    var stdString = "STDS are";
                                    for std in STDVALS {
                                        stdString = ":".join(stdString, std);
                                    } 
                                    writef("--------------------------------NOT Stable SRCC Values are: %s\n", stdString);
                                    writeln("--------------------------------\n");
                                }
                            }
                        }
                    }
                } 
                writeln("---------------------------------Updating Master Tables Done!---------------------------------------\n");
                writeln("****************************************************************************************************\n");
                MasterTablesAvailable$.writeEF(1);
            }
            proc getBeginPADDSVar(){
                return BeginPADDSVar;
            }
            proc setBeginPADDSVar(value:string){
                BeginPADDSVar = value;
            }
            proc getBeginPADSSFBest(){
                return this.BeginPADSSFBest;
            }
            proc setBeginPADSSFBest(value:real){
                this.BeginPADSSFBest = value;
            }
            /* This is For Multi Objective Calibration */
            proc FillMasterTablesMultiObjective(CheckSRCCValues: bool, StopCriterion:string){

                var lock = MasterTablesAvailable$.readFE();
                writeln("*******************************************************************************************\n");
                writeln("--------------------------------Updating Master Tables-------------------------------------");
                

                record InsertData{
                    var hostname: string;
                    var hostID: int;
                    var PureData: list(RowsForMasterTablesFunctionalMulti);
                    var FBest: real;
                    var MashineParameterSet: list(shared Parameter, parSafe=true);
                    var DDSVariable: string;
                    var DDSIndicators: list(string);
                    proc init(host:string, id:int, Data: list(RowsForMasterTablesFunctionalMulti), Fbest: real, ParameterSet: list(shared Parameter, parSafe=true), Variable: string, Indicators: list(string)){
                        this.hostname = host;
                        this.hostID = id;
                        this.PureData = Data;
                        this.FBest = Fbest;
                        this.MashineParameterSet = ParameterSet; 
                        this.DDSVariable = Variable; 
                        this.DDSIndicators = Indicators;
                    }
                }
                var AllInsertData: list(InsertData);
                var DoCrowdingDis: list(bool);
                var HaveRepeatedItem: bool = false;
                var CurrentParameterSet: list(shared Parameter, parSafe=true);

                for M in MachinesMulti{ 
                    if (M.DataforMasterTables.size != 0) {
                        var readvalue = M.WriteToMasterTables$.readFE();
                        var Mdata = new InsertData(M.hostName, M.hostID, M.DataforMasterTables, M.Fbest, M.CurrentParameterSet, M.DDSVariableName, M.DDSIndicatorName);
                        M.DataforMasterTables.clear();
                        AllInsertData.append(Mdata);
                        CurrentParameterSet = M.CurrentParameterSet;
                        M.WriteToMasterTables$.writeEF(true);
                    }
                }
                for M in MachinesMulti{
                    if (M.NumberofObjectives <= M.objectivesDone && M.RepeatVariable == ""){
                        DoCrowdingDis.append(true);
                    }
                }
                if (DoCrowdingDis.size == MachinesMulti.size) {
                    for M in MachinesMulti{ 
                        writeln("--------------------------------The Crowding Distance Will Begin....");
                        writeln("--------------------------------");
                        writef("--------------------------------Number of Objectives on %s: %s", M.hostName, M.NumberofObjectives);
                        writeln("--------------------------------");
                        writef("--------------------------------Number of Done Objectives on %s: %s", M.hostName, M.objectivesDone);
                        writeln("--------------------------------");
                        break;
                    }
                }
                var ArchiveBestParset: list(shared Parameter, parSafe=true);
                var ArchiveFBests: real;
                var MasterArchiveParSet: list(shared Parameter, parSafe=true);
                var CurSimID: string;
                var Masterarchive: list(string);
                var MRDStopCriterion: real; 
                var BeginPADDSLVar: string = "NOTSET";

                for InsertRow in AllInsertData{
                    var hostname = InsertRow.hostname;
                    var hostid = InsertRow.hostID;
                    var DDSVariable = InsertRow.DDSVariable;
                    var DDSIndicators = InsertRow.DDSIndicators;
                    var MachineFBest = InsertRow.FBest;
                    var MachineBestParset = InsertRow.MashineParameterSet;
                    for Indiv in InsertRow.PureData{
                        var varname: list(string);
                        var IndicName: list(string);
                        var Indicvalue: list(string);
                        var WIndicvalue: list(string);
                        var ProgramDB = new ProgramDatabase(ProjectPath, ProjectName, InsertRow.hostname, InsertRow.hostID);
                        for row in Indiv.PerformanceResult{
                            varname.append(row[0]);
                            IndicName.append(row[3]);
                            Indicvalue.append(row[5]);
                            WIndicvalue.append(row[4]);
                        }
                        //ProgramDB.UpdateMasterTablesFunctional(hostname, ProjectName, Indiv.SimID, Indiv.ParsetId, "Start", "End", 0, Indiv.ParmeterSet.getParameterSet(), varname, IndicName, Indicvalue, WIndicvalue);
                        ProgramDB.UpdateMasterTablesFunctional(hostname, ProjectName, Indiv.SimID, Indiv.ParsetId, Indiv.IMWEBsEndTimeDate, Indiv.IMWEBsStartTimeDate, Indiv.IMWEBsSimulationRunTime:real, Indiv.ParmeterSet.getParameterSet(), varname, IndicName, Indicvalue, WIndicvalue);
                        if (DDSVariable.size != 0 && DDSIndicators.size == 0){
                            writeln("--------------------------------BeginPADDS Stage is Going on Currently on the Master Node!\n");
                            writeln("--------------------------------\n");

                            if (getBeginPADDSVar().startsWith("NONE") == true && BeginPADDSLVar.startsWith(DDSVariable) == false) {
                                setBeginPADDSVar(DDSVariable);
                                BeginPADDSLVar = DDSVariable;
                            }
                            if getBeginPADDSVar().startsWith(DDSVariable) == true {
                                if (getBeginPADSSFBest() > MachineFBest){
                                    setBeginPADSSFBest(MachineFBest);
                                    ArchiveFBests = MachineFBest;
                                    ArchiveBestParset = MachineBestParset;
                                    var IndicNm: string; 
                                    ProgramDB.getLocalFValue(false);
                                    ProgramDB.Archive_Update(Indiv.ParmeterSet, Indiv.TotalF, Indiv.VariableName, IndicNm, true);
                                    if (ProgramDB.getDominanceStatus() == "ADDED"){
                                        writef("--------------------------------Master Best Archive has been Updated. Return is %s\n", ProgramDB.getDominanceStatus());
                                        writeln("--------------------------------\n");
                                        CurSimIDMaster = ProgramDB.getcurentSimID(); 
                                        ArchiveFBests = Indiv.TotalF;
                                        ArchiveBestParset = Indiv.ParmeterSet.getParameterSet();
                                        CurParSetMaster = Indiv.ParmeterSet.getParameterSet();
                                    }
                                }
                                if (getBeginPADSSFBest() < 0.4 && getBeginPADSSFBest() > -0.2){
                                    writef("--------------------------------DDS Stage for Objective %s has been over with TotalF Equal to %s\n", Indiv.VariableName, getBeginPADSSFBest():string );
                                    writeln("--------------------------------\n");
                                    setBeginPADSSFBest(999);
                                    setBeginPADDSVar("NONE");
                                    HaveRepeatedItem = false;
                                } else {
                                    HaveRepeatedItem = true; 
                                    writef("--------------------------------DDS Stage for Objective %s will be continued\n",Indiv.VariableName);
                                    writeln("--------------------------------\n");
                                    for M in MachinesMulti{
                                        M.setRepeatVariable(DDSVariable);
                                    }
                                }
                            }
                        } else if (Indiv.VariableName.size != 0 && Indiv.IndicatorName.size != 0) {
                            writeln("--------------------------------- We are Still in the BeginPADDS on the Master Node!---------------------------------\n");
                            for indic in Indiv.IndicatorName{
                                ProgramDB.getLocalFValue(false);
                                ProgramDB.Archive_Update(Indiv.ParmeterSet, InsertRow.FBest, Indiv.VariableName, indic, true); 
                                if (abs(ProgramDB.getBestF()) != 99){
                                    writef("---------------------------------Update News: GlobalF value based on the Master Archive is %s on Machine %s\n--------------------------------------", (ProgramDB.getBestF()):string, here.hostname);
                                    ArchiveBestParset = ProgramDB.getBestParArchive();
                                    ArchiveFBests = ProgramDB.getBestF();
                                    var FirstString = ":".join(ArchiveBestParset.getValue(0).getParName(), ArchiveBestParset.getValue(0).getCurrentValue():string);
                                    for i in 1..ArchiveBestParset.size-1{
                                        var Parameter = ":".join(ArchiveBestParset.getValue(i).getParName(), ArchiveBestParset.getValue(i).getCurrentValue():string);
                                        FirstString = "--".join(FirstString, Parameter);
                                    }
                                    writef("------------------------------------BeginPADDS: Master Archive's Best ParameterSet is %s------------------------------------\n", FirstString);
                                }
                                if (ProgramDB.getDominanceStatus() != "ADDED"){
                                    writef("--------------------------------------Master Best Archive has not been Updated. Return is %s-------------------------------------\n", ProgramDB.getDominanceStatus());
                                    writef("--------------------------------- Hence the Workers are going to Repeat the Simulations for Varibale %s---------------------------------\n", Indiv.VariableName);
                                    HaveRepeatedItem = true; 
                                    for M in MachinesMulti{
                                        if (M.hostName == hostname) {
                                            M.setRepeatVariableIndicatorandFBest(Indiv.VariableName, indic);
                                        }
                                    }
                                } else {
                                    CurSimIDMaster = Indiv.SimID; 
                                    CurParSetMaster = Indiv.ParmeterSet.getParameterSet();
                                    writef("-------------------------------------Master Best Archive has been Updated. Return is %s------------------------------------\n", ProgramDB.getDominanceStatus());
                                    writeln("--------------------------------- Hence the Workers are going to Work on a New Objective---------------------------------\n");
                                }
                            }
                        } else if (Indiv.VariableName.size == 0 && Indiv.IndicatorName.size == 0) {
                            var VarNm: string;
                            var IndicNm: string;
                            ProgramDB.getLocalFValue(false);
                            writeln("--------------------------------We are in the PADDS on the Master Node!\n");
                            writeln("--------------------------------\n");
                            ProgramDB.Archive_Update(Indiv.ParmeterSet, 99, VarNm, IndicNm, false);
                            if (ProgramDB.getDominanceStatus() != "ADDED"){
                                CurSimID = CurSimIDMaster;
                                CurrentParameterSet = ProgramDB.CrowdingDistance(ProgramDB.getBestParArchive(), MultiobjectiveType);
                            } else {
                               CurSimID = Indiv.SimID;
                               CurSimIDMaster = CurSimID;
                               CurrentParameterSet = Indiv.ParmeterSet.getParameterSet();
                            }
                            MasterArchiveParSet = CurrentParameterSet;
                            Masterarchive = ProgramDB.getanArchivebySimID(CurSimID);

                            var FirstString = Masterarchive[0];
                            for i in 1..Masterarchive.size-1{
                                FirstString = "--".join(FirstString, Masterarchive[i]);
                            }
                            var SecondString = ":".join(MasterArchiveParSet.getValue(0).getParName(), MasterArchiveParSet.getValue(0).getCurrentValue():string);
                            for i in 1..MasterArchiveParSet.size-1{
                                var Parameter = ":".join(MasterArchiveParSet.getValue(i).getParName(), MasterArchiveParSet.getValue(i).getCurrentValue():string);
                                SecondString = "--".join(SecondString, Parameter);
                            }
                            writef("--------------------------------PADDS: Master Archive's Best ParameterSet is %s\n", SecondString);
                            writeln("--------------------------------\n");
                            writef("--------------------------------PADDS: Master Archive is %s\n", FirstString);
                            writeln("--------------------------------\n");
                            MRDStopCriterion = ProgramDB.getStoppingMDR();
                            writef("--------------------------------PADDS: The MRD Stopping Criterion is %s\n", MRDStopCriterion:string);
                            writeln("--------------------------------\n");
                        }
                        if (CheckSRCCValues == true){
                            var SRCCobject = new ParametersetUpdate(ProjectPath);
                            var SRCCValues: list(shared ParametersSRCCValues);
                            writeln("--------------------------------Calculating SRCC Values is taking place!\n");
                            writeln("--------------------------------\n");
                            SRCCValues = SRCCobject.SRCCStableValue(Indiv.SimID, ProjectName, "ALL");
                            if (SRCCValues.size != 0){
                                writeln("--------------------------------Stable SRCC Values have been Achieved!\n");
                                writeln("--------------------------------\n");
                                var SRCCString: string; 
                                for M in SRCCValues{
                                    if (SRCCString.size == 0){
                                        var LocalString = M.ParameterCalibrationID:string;
                                        LocalString = ":".join(LocalString, M.SRCCValue:string);
                                        SRCCString = LocalString;
                                    } else {
                                        var LocalString = M.ParameterCalibrationID:string;
                                        LocalString = ":".join(LocalString, M.SRCCValue:string);
                                        SRCCString = "--".join(SRCCString, LocalString);
                                    }
                                }
                                writef("--------------------------------Stable SRCC Values are %s\n", SRCCString);
                                writeln("--------------------------------\n");
                                for machine in MachinesMulti{
                                    machine.SetSRCCvalues(SRCCValues);
                                }
                            } else {
                                var STDVALS= SRCCobject.getSTDValues();
                                if (STDVALS.size == 0){
                                    writeln("--------------------------------Calculation of SRCC Values' Standard Deviation is Not Started Yet (Not Enough Simulations have been done)\n");
                                    writeln("--------------------------------\n");
                                } else {
                                    var stdString = "STDS are:";
                                    for std in STDVALS {
                                        stdString = ":".join(stdString, std);
                                    } 
                                    writef("--------------------------------NOT Stable SRCC Values! %s\n", stdString);
                                    writeln("--------------------------------\n");
                                }
                            }
                        }
                    }
                }
                if (DoCrowdingDis.size == MachinesMulti.size && HaveRepeatedItem == false){
                    writeln("--------------------------------Crowding Distance is taking Place! The PADDS will start on Worker Nodes!\n");
                    writeln("--------------------------------\n");
                    var CrowdingDistancePar = PrDB.CrowdingDistance(ArchiveBestParset, MultiobjectiveType);
                    for M in MachinesMulti{
                        M.crowdingDistanceParSet = CrowdingDistancePar;
                        M.objectivesDone = 0;
                    }
                }
                if (ArchiveBestParset.size != 0){
                    writeln("--------------------------------PADDS First Stage: The Best Archive Parameter Set and its associated FBest for Worker Nodes got Updated!\n");
                    writeln("--------------------------------\n");
                    
                    for MA in MachinesMulti{
                        MA.BestParSetArchive = ArchiveBestParset;
                        MA.setArchiveFBest(ArchiveFBests);
                    } 
                } else {
                    for MA in MachinesMulti{
                        if (MA.BestParSetArchive.size != 0){
                            MA.BestParSetArchive = new list(shared Parameter, parSafe=true);
                            MA.setArchiveFBest(999);
                        }
                    }
                }
                if (MasterArchiveParSet.size != 0){
                    writeln("--------------------------------PADDS Second Stage: The Best Archive Parameter Set for Worker Nodes got Updated!\n");
                    writeln("--------------------------------\n");
                    for MA in MachinesMulti{
                        MA.BestParSetArchive = MasterArchiveParSet;
                        MA.MasterArchive = Masterarchive;
                    }
                }
                var StoppingCriterionValue: real;
                var ParetoFront = ParetoFrontMaster;
                var ReadGDThreshold = GDThreshold;
                if (StoppingCriterion == "FV-STD" || StoppingCriterion == "CD-STD" ){
                    StoppingCriterionValue = 0.05; // If we are working with STD, then the STD of all objectives for the last 10 simulations should be less than 0.05 to stop 
                } else {
                    StoppingCriterionValue = 0; // If we are working with MDR, then the MRD value of the last 10 runs suoud be 0 to stop 
                }
                /* Upadte the Stopping Criterion */ 
                if (StopCriterion == "FV-STD") {
                    writeln("--------------------------------Checking Stopping Criterion (FV-STD) is Taking Place\n");
                    writeln("--------------------------------\n");
                    var ArchiveStats = PrDB.getValueForStoppingCriterionSTD(MultiobjectiveType);
                    ArchiveStatsListFVS.append(ArchiveStats);
                    writef("--------------------------------The Number of FV-STD Values we have is %s\n", ArchiveStatsListFVS.size:string);
                    writeln("--------------------------------\n");
                    if (ArchiveStatsListFVS.size == 20){ 
                        writeln("--------------------------------Evaluation of whether the Calibration need to Stop or not has started\n");
                        writeln("--------------------------------\n");
                        var FirstArchive = ArchiveStatsListFVS.getValue[0];
                        var n = FirstArchive.size/2 - 1;
                        var MaxIHomogenity: list(real);
                        for arch in ArchiveStatsListFVS {
                            var TempValue:real = 0;
                            for i in 0..n {
                               if (arch[(2*i) +1].startsWith("N") == false) {
                                    if (arch[(2*i) +1]: real > TempValue){
                                        TempValue = arch[(2*i) +1]: real;
                                    }
                               }
                            }
                            MaxIHomogenity.append(TempValue);
                        }
                        var MaxFVSTD: real = 0;
                        for v in MaxIHomogenity{
                            if (v > MaxFVSTD){
                                MaxFVSTD = v;
                            }
                        }
                        writef("--------------------------------The Max Value for FV-STD is found as %s\n", MaxFVSTD:string);
                        writeln("--------------------------------\n");
                        if (MaxFVSTD < StoppingCriterionValue){
                            if (ParetoFront == false ){
                                writeln("--------------------------------Stopping Criterion Condition is Reached! The Calibration will Stop Soon\n");
                                writeln("--------------------------------\n");
                                for M in MachinesMulti{
                                    if (M.hostID == here.id){
                                        M.UpdatedStopingCriterionValue = MaxFVSTD;
                                    }
                                }
                            } else {
                                var GDvalue = PrDB.gettheGDValue(MultiobjectiveType);
                                if (GDvalue <= GDThreshold){
                                    for M in MachinesMulti{
                                        M.UpdatedStopingCriterionValue = MaxFVSTD;
                                    }
                                } else {
                                    setInitialParameterSetFunctional(); /* If the algorithm has got stuck in a space, which is not the true convergence, 
                                    we need to give it a random parameter set to start with and get out of the "local" optimal */
                                    for M in MachinesMulti{
                                        M.BestParSetArchive = new list(shared Parameter, parSafe=true);
                                        M.UpdatedStopingCriterionValue = 0;
                                        M.CurrentArchive.clear();
                                        M.BestParSetArchive.clear();
                                        M.MasterArchive.clear();
                                        var lock = M.WriteToMasterTables$.readFE();
                                        M.DataforMasterTables.clear();
                                        M.WriteToMasterTables$.writeEF(lock);
                                    }
                                }
                            }
                        }
                        else {
                            writeln("--------------------------------Stopping Criterion Condition is NOT Reached! The Calibration will Continue\n");
                            writeln("--------------------------------\n");
                            for M in MachinesMulti{
                                M.UpdatedStopingCriterionValue = MaxFVSTD;
                            }
                        }
                        ArchiveStatsListFVS.clear();
                    }
                }
                /* Not Checked */   
                if (StopCriterion == "MDR"){
                    if (StoppingCriterionList.size != 10){ //We check if the MDR of the last 10 simulations are all 0 --> stop the algorithm
                        StoppingCriterionList.append(MRDStopCriterion);
                    } else if (StoppingCriterionList.size == 10){
                        StoppingCriterionList.pop(0);
                        StoppingCriterionList.append(MRDStopCriterion);
                    }
                    if (StoppingCriterionList.size == 10){
                        var numerofzeros: list(bool);
                        for i in StoppingCriterionList {
                            if (i == 0){
                                numerofzeros.append(true);
                            } else {
                                numerofzeros.append(false);
                            }
                        }
                        if (numerofzeros.contains(false) == false){
                            for M in MachinesMulti{
                                M.UpdatedStopingCriterionValue = 0;
                            }
                        } else {
                        for M in MachinesMulti{
                                M.UpdatedStopingCriterionValue = 100;
                            }
                        }
                    }
                }
                /* Not Checked */                 
                if (StoppingCriterion == "CD-STD"){
                    var ArchiveStats = PrDB.getValueForCrowdingDistanceSTD(MultiobjectiveType);
                    ArchiveStatsList.append(ArchiveStats);
                    if (ArchiveStatsList.size == 20){ //after 20 runs?
                        var MaxCDSTD: real = 0;
                        for v in ArchiveStatsList {
                            if (v > MaxCDSTD){
                                MaxCDSTD = v;
                            }
                        }
                        if (MaxCDSTD < StoppingCriterionValue){
                            if (ParetoFront == false ){
                                for M in MachinesMulti{
                                    if (M.hostID == here.id){
                                        M.UpdatedStopingCriterionValue = MaxCDSTD;
                                    }
                                }
                            } else {
                                var GDvalue = PrDB.gettheGDValue(MultiobjectiveType);
                                if (GDvalue <= ReadGDThreshold){
                                    for M in MachinesMulti{
                                        if (M.hostID == here.id){
                                            M.UpdatedStopingCriterionValue = MaxCDSTD;
                                        }
                                    }
                                } else {
                                    setInitialParameterSetFunctional(); /* If the algorithm has got stuck in a space, which is not the true convergence, 
                                    we need to give it a random parameter set to start with and get out of the "local" optimal */
                                    for M in MachinesMulti{
                                        M.BestParSetArchive = new list(shared Parameter, parSafe=true);
                                        M.UpdatedStopingCriterionValue = 0;
                                        M.CurrentArchive.clear();
                                        M.BestParSetArchive.clear();
                                        M.MasterArchive.clear();
                                        var lock = M.WriteToMasterTables$.readFE();
                                        M.DataforMasterTables.clear();
                                        M.WriteToMasterTables$.writeEF(lock);
                                    }
                                }
                            }
                        }
                        else {
                            for M in MachinesMulti{
                                M.UpdatedStopingCriterionValue = MaxCDSTD;
                            }
                        }
                        ArchiveStatsList.clear();
                    }
                }
                writeln("--------------------------------Updating Master Tables Done!-------------------------------------\n");
                writeln("****************************************************************************************************\n");
                MasterTablesAvailable$.writeEF(1);  
            }
            /* --------------------------------Functional Functions ------------------------------------- */
            proc setInitialParameterSetFunctional(){ 
                
                var PS = new shared ParameterSetInitialization(ProjectPath, true);
                var ParameterSet = PS.getParameterSet();
                var rng = new RandomStream(real);
                for par in ParameterSet{
                    var RandomValue = rng.getNext(min = par.getLowerValue(), max = par.getUpperValue());
                    par.setCurrentValue(RandomValue);
                    par.setBestValue(RandomValue);
                }
                if (CalibrationType == "Single-Objective"){
                    for machine in MachinesSingle{
                        machine.BestParSet = ParameterSet;
                    }
                } else if (CalibrationType == "Multi-Objective"){

                    for machine in MachinesMulti{
                        for par in ParameterSet{
                            var RandomNumber = rng.getNext(min = par.getLowerValue(), max = par.getUpperValue());
                            par.setCurrentValue(RandomNumber);
                            par.setBestValue(RandomNumber);
                        }
                        machine.CurrentParameterSet = ParameterSet;
                    }
                }
            }
            proc getFBestValue(hostId:int) {
                
                var Fbest: real;
                if (MachinesMulti.size == 0){
                    for m in MachinesSingle {
                        if (m.hostID == hostId){
                            Fbest = m.Fbest;
                        }
                    }
                } else if (MachinesSingle.size == 0){
                    for m in MachinesMulti{
                        if (m.hostID == hostId){
                            Fbest = m.Fbest;
                        }
                    }
                }
                return Fbest;
            }
            proc getArchiveParameterSet(hostId:int) {

                var BestParset: list(shared Parameter, parSafe=true);
                if (MachinesMulti.size == 0){
                    for m in MachinesSingle{
                        if (m.hostID == hostId){
                            BestParset = m.BestParSetArchive;
                        
                        }
                    }
                } else if (MachinesSingle.size == 0){
                    for m in MachinesMulti{
                        if (m.hostID == hostId){
                            BestParset = m.BestParSetArchive;
                        }
                    }
                }
                return BestParset;
            }
            proc getArchiveFBestValue(hostId:int){

                var FBestArch: real;
                if (MachinesMulti.size == 0){
                    for m in MachinesSingle{
                        if (m.hostID == hostId){
                            FBestArch = m.FbestArchive;
                        }
                    }
                }
                if (MachinesSingle.size == 0){
                    for m in MachinesMulti{
                        if (m.hostID == hostId){
                            FBestArch = m.ArchiveFBest;
                        }
                    }
                }
                return FBestArch;
            }
            proc getSRCCValues(hostId:int){

                var SRCC: list(shared ParametersSRCCValues);
                if (MachinesMulti.size == 0){
                    for m in MachinesSingle{
                        if (m.hostID == hostId){
                            SRCC = m.SRCCStableResults;
                        }
                    }
                } else if (MachinesSingle.size == 0){
                    for m in MachinesMulti{
                        if (m.hostID == hostId){
                            SRCC = m.SRCCStableResults;
                        }
                    }
                }
                return SRCC;
            }
            /* This function is read by a worker node before starting a simulation to get the parameters and after the simulation to set the parameter set
            For the Dependent Mult-Search, this function is read once , at the beginning of the program, to get the initial parameter set 
            */
            proc getParameterSet(hostId:int) {

                var BestParset: list(shared Parameter, parSafe=true);
                if (MachinesMulti.size == 0){
                    for m in MachinesSingle{
                        if (m.hostID == hostId) {
                            BestParset = m.BestParSet;
                        }
                    }
                } else if (MachinesSingle.size == 0){
                    for m in MachinesMulti{
                        if (m.hostID == hostId) {
                            BestParset = m.CurrentParameterSet;
                        }
                    }
                }
                return BestParset;
            }
            proc hasSRCCValuesSet(hostId:int) {

                var returnvalue: bool;
                if (MachinesMulti.size == 0){
                    var Machines = MachinesSingle;
                    for m in Machines {
                        if (m.hostID == hostId){
                            if (m.SRCCStableResults.size != 0){
                                returnvalue = true;
                            } else {
                                returnvalue = false;
                            }
                        }
                    }
                }
                if (MachinesSingle.size == 0){
                    var Machines = MachinesMulti;
                    for m in Machines {
                        if (m.hostID == hostId){
                            if (m.SRCCStableResults.size != 0){
                                returnvalue = true;
                            } else {
                                returnvalue = false;
                            }
                        }
                    }
                }
                return returnvalue;
            }
            coforall loc in 0..MyRemoteLocales.size-1 do{
                on MyRemoteLocales[loc] do{
                    /* My assumption here is that we divide the Entire simulations that we want to run, 
                    among Locales equally. We have to give a ToatalSimulationNumber to the DDS
                    and PADDS algorithms to make them run. So this TotalSimulations is ONLY a
                    number for those algorithms and also the stopping criterion when our 
                    measure scope is the Convergence */
                    var TotalSimulations = EntireSimulationNumbers/MyRemoteLocales.size;
                    /* Creating an object of the ProgarmDatabse class to have access to its methods and global variables
                    The project name is the name in the BaseProject Table */
                    var ProgramDBClass = new ProgramDatabase(ProjectPath, ProjectName);
                    /* The point here is that since we do not have access to all the tables, we work with 
                    the secondary initializer to create an object of the Parameter initialization class */
                    /* Declaring SimID, ParSet ID, and other variables */
                    var SimIDint: int = 0;
                    var SimControl: int = 0;
                    var ComputerUpdateDone = false;
                    var SimID: string = "0";
                    var CheckSRCCValues: bool;
                    var SRCCValues: list(shared ParametersSRCCValues);
                    var ParSetID: string; 
                    var StoppingCriterionMethod = StoppingCriterion; 
                    var StoppingCriterionValue: real;
                    var InitialPADDS = 0; 
                    var DDSCounterSimIDsimulator: int = 0 ; /* Since Simulation ID is not a "real" number, and the DDS function need a real
                    number simulation ID, we create a simulator for the Simulation ID, by adding a counter which gets added one each time the DDS function wants to run */
                    /* We need to add context for the measurement Database to the EF core Database */ 
                    var configuration = new Config(ProjectPath);
                    //configuration.addMeasurementContext(); /* To add a Context for the measurement database in our EF core Project */
                    /* From here the loop for the single objective starts */ 
                    if (CalibrationType == "Single-Objective"){ 
                           
                        var BestOFValue = getFBestValue(here.id); /* We have already filled the best value for all machines to a  number --> 999, We need to read it here */
                        var Leftside: real;
                        var Rightside: real;
                        var PS = new shared ParameterSetInitialization(ProjectPath);
                        // The next step is to read the assigned parameter set to this machine and set it to this object
                        PS.setParameterSet(getParameterSet(here.id));
                        /* If we aim to measure " How fast does our algorithm run?" we need to have the same stopping criterion across the cluster, 
                        which it should be the Value of the Best Objective Function. In fact, we measure how fast the algorithm can get to the point where its objective function is this Stopping Value. */
                        if (MeasureScope == "Speed"){
                            Leftside = BestOFValue;
                            Rightside = DesiredObjectiveValue; // The Value that we aim to obtain for the Single_objective Calibration
                        }
                        if (MeasureScope == "Convergence"){
                            Leftside = SimControl;
                            Rightside = TotalSimulations;
                        }
                        var RunFailedSimulation = false;
                        var TotalFailedSimulationsRunBythisMachine: int; 
                        while (Leftside < (Rightside + 1 )){    
                        
                            try {
                                var hostImfailed: string;
                                if (MeasureScope == "Speed") {
                                    if (DDSCounterSimIDsimulator >= TotalSimulations){ /* If the desired accuracy has not been obtained before the total number of simulations assigned to the machine gets reached, we need to in Total Simulation number */
                                        TotalSimulations = TotalSimulations + 2;
                                        writef("--------------------------------The Number of Simulations on Node %s has been Increased\n", here.hostname);
                                    }
                                }  
                                if (MeasureScope == "Convergence"){ /* If the machine is taking over failed simulation, we need to increase its allocated simulation Number */
                                    if (TotalFailedSimulationsRunBythisMachine != 0){
                                        TotalSimulations = TotalSimulations + TotalFailedSimulationsRunBythisMachine;
                                        TotalFailedSimulationsRunBythisMachine = 0;
                                        writef("--------------------------------Due to an IMWEBs failed run, the number of simulations on %s got incresed\n", here.hostname);
                                        Rightside = TotalSimulations;
                                    }
                                }
                                var MachinesBestF: list(real); /* A list to get the ID of Machines for which the BestFoundMin has been found, 
                                Each machine should get the best-found values and compare it with its own, and get the best one and then continue  */ 
                                for machine in MachinesSingle {
                                    if (machine.Fbest != 999){ // It means it has found a Min F value
                                        MachinesBestF.append(machine.Fbest);
                                    }
                                }
                                var FialedMachineHostID: int = 0;
                                var FailedSimID: string = "0" ;
                                var FailedPar: string;
                                for Failed in IamFailedList{
                                    if (Failed.Numfailed != 0){
                                        var lock = readFaildList$.readFE();
                                        FialedMachineHostID = Failed.HostID;
                                        if (Failed.SimID.size != 0){
                                            FailedSimID = Failed.SimID.pop();
                                            FailedPar = Failed.ParID.pop();
                                            if (Failed.SimID.size == 0){
                                                Failed.Numfailed = Failed.Numfailed-1;
                                            }
                                        }
                                        TotalFailedSimulationsRunBythisMachine = TotalFailedSimulationsRunBythisMachine + 1;
                                        readFaildList$.writeEF(true);
                                        break;
                                    }
                                }
                                if (FialedMachineHostID != 0) { /* Here we read one of machines is that need to be taken over, and set its status to false to inform other machines that this machine responsibility has been taken over*/
                                    if (FailedSimID == "0") { // If the machine which has been failed only has shared the ParameterS it had
                                        PS.setParameterSet(getParameterSet(FialedMachineHostID));
                                        SimIDint = SimuID$.readFE(); // Read a new simulation ID
                                        SimuID$.writeEF(SimIDint + 1);
                                        PS.setSimulationID(SimIDint);
                                        for M in MachinesSingle{
                                            if (M.hostID == FialedMachineHostID){
                                                hostImfailed = M.hostName;
                                            }
                                            if (M.Fbest != 999) { // Read Best F value if it has 
                                                BestOFValue = M.Fbest;
                                            } else {
                                                BestOFValue =getFBestValue(here.id);
                                            }
                                        }
                                        ParSetID = "_".join(hostImfailed, SimIDint:string);
                                        PS.setParameterSet_ID(ParSetID);
                                        var SimIDstring = "".join(0:string, FialedMachineHostID:string, SimIDint:string);
                                        SimID = SimIDstring;
                                        RunFailedSimulation = true;
                                    } else { // If the failed Machine also has shared ParSet ID and Simulation ID 
                                        PS.setParameterSet(getParameterSet(FialedMachineHostID));
                                        PS.setParameterSet_ID(ParSetID);
                                        SimID = FailedSimID;
                                        ParSetID = FailedPar;
                                        RunFailedSimulation = true;
                                    }
                                    var Machineisthere:bool = false;
                                    for info in ComCpuInfo {
                                        if (info.UpdateComHostIDs != FialedMachineHostID){ /* If the Locale actually has failed in the first simulation and 
                                            the Computer table and CPU table have to wait for the info from this Computer --> We need to give the info and let the Master Node update these two tables  */
                                            Machineisthere = true;
                                        }
                                    }
                                    if (Machineisthere == false){
                                        for Com in ComCpuInfo{
                                            if (Com.UpdateComHostIDs == FialedMachineHostID){
                                                Com.StartSimIDs = SimID;
                                                Com.TotalSimIDs = TotalSimulations;
                                                
                                            }
                                        }
                                        var numfinishedcoms: int = 0;
                                        for Com in ComCpuInfo{
                                            if (Com.StartSimIDs != "0"){
                                                numfinishedcoms = numfinishedcoms+1;
                                                
                                            }
                                        }
                                        if (numfinishedcoms == MachinesSingle.size){
                                            on Locales[0]{
                                                updateComputerInfos();
                                            }
                                        }
                                    }
                                } else if (MachinesBestF.size != 0){
                                    var MinFBest = min reduce(MachinesBestF); // If we have other Best F, get the Min one
                                    if (MinFBest < BestOFValue){
                                        var updatedBestParSet: list(shared Parameter, parSafe=true);
                                        for machine in MachinesSingle {
                                            if (machine.Fbest == MinFBest){
                                                updatedBestParSet = machine.BestParSet;
                                            }
                                        }
                                        for par in PS.getParameterSet(){
                                            for para in updatedBestParSet{
                                                if (par.getParName() == para.getParName()){
                                                    par.setCurrentValue(para.getBestValue());
                                                    par.setBestValue(para.getBestValue());
                                                }
                                            }
                                        }
                                        writeln("--------------------------------Updating the Parameters' values based on Minimun F Value found on all Machines\n");
                                        BestOFValue = MinFBest;
                                    } else {
                                        PS.setParameterSet(getParameterSet(here.id));
                                        BestOFValue = getFBestValue(here.id);
                                    }
                                    SimIDint = SimuID$.readFE(); 
                                    SimuID$.writeEF(SimIDint + 1);
                                    PS.setSimulationID(SimIDint);
                                    ParSetID = "_".join(here.hostname, SimIDint:string);
                                    PS.setParameterSet_ID(ParSetID);
                                    var SimIDstring ="".join(0:string, here.id:string, SimIDint:string);
                                    SimID = SimIDstring;
                                } else {
                                    
                                    SimIDint = SimuID$.readFE();
                                    SimuID$.writeEF(SimIDint + 1);
                                    PS.setSimulationID(SimIDint);
                                    ParSetID = "_".join(here.hostname, SimIDint:string);
                                    PS.setParameterSet_ID(ParSetID);
                                    var SimIDstring ="".join(0:string, here.id:string, SimIDint:string);
                                    SimID = SimIDstring;
                                    PS.setParameterSet(getParameterSet(here.id));
                                    BestOFValue = getFBestValue(here.id);
                                }
                                if (ComputerUpdateDone ==  false) { // We need to update two Computers and CPU tables on the Master Node 
                                    for Com in ComCpuInfo{
                                        if (Com.UpdateComHostIDs == here.id){
                                            Com.StartSimIDs = SimID;
                                            Com.TotalSimIDs = TotalSimulations;
                                        }
                                    }
                                    var numfinishedcoms: int = 0;
                                    for Com in ComCpuInfo{
                                        if (Com.StartSimIDs != "0"){
                                            numfinishedcoms = numfinishedcoms+1;
                                        }
                                    }
                                    if (numfinishedcoms == MachinesSingle.size){
                                        on Locales[0]{
                                            updateComputerInfos();
                                        }
                                    }
                                    ComputerUpdateDone = true; 
                                }
                                if (MeasureScope == "Speed"){
                                    Leftside = BestOFValue;
                                }
                                try {    
                                    if (CalibrationAlgorithm == "DDS"){
                                        writeln("--------------------------------DDS Functional Algorithm is being used.....\n");
                                        writeln("--------------------------------\n");
                                        var DDSobject = new ParametersetUpdate(ProjectPath);
                                        DDSCounterSimIDsimulator = DDSCounterSimIDsimulator + 1;
                                        PS.setParameterSet(DDSobject.DDSFunctional(PS.getParameterSet(), DDSCounterSimIDsimulator, TotalSimulations));
                                    }
                                    if (CalibrationAlgorithm == "SRCC-DDS"){
                                        writeln("--------------------------------SRCC-DDS Algorithm is being used.....\n");
                                        writeln("--------------------------------\n");
                                        if (hasSRCCValuesSet(here.id) == false) {
                                            var SRCCobject = new ParametersetUpdate(ProjectPath);
                                            DDSCounterSimIDsimulator = DDSCounterSimIDsimulator + 1;
                                            PS.setParameterSet(SRCCobject.DDSFunctional(PS.getParameterSet(), DDSCounterSimIDsimulator, TotalSimulations));
                                            CheckSRCCValues = true;
                                        }
                                        else if (hasSRCCValuesSet(here.id) == true){
                                            CheckSRCCValues = false;
                                            var SRCCobject = new ParametersetUpdate(ProjectPath);
                                            SRCCValues = getSRCCValues(here.id);
                                            PS.setParameterSet(SRCCobject.SRCCDDSFunctional(PS.getParameterSet(), SRCCValues));
                                        }
                                    }
                                    var IMWEBSsuccess = false;
                                    var IMWEBsSimulation = new IMWEBs(PS.getParameterSet(), ProjectName, ProjectPath);
                                    IMWEBSsuccess= IMWEBsSimulation.RunModel(HDF5Path, IMWEBsbashfilePath);
                                    if (IMWEBSsuccess == true){
                                        if (MeasureScope == "Convergence"){
                                            SimControl = SimControl + 1;
                                            Leftside = SimControl;
                                        }
                                        if (MeasureScope == "Speed"){
                                            Leftside = BestOFValue;
                                        }
                                        var PerformanceResults = ProgramDBClass.getSimulationPerformanceResults(SimID, ParSetID); 
                                        var AchievedFValue =  ProgramDBClass.getSingleObjectiveValue(PerformanceResults, SingleObjIndicatorName);
                                        writef("--------------------------------New F value has been Found which is %s on Node: %s \n",AchievedFValue, here.hostname);
                                        if (abs(AchievedFValue) < abs(BestOFValue)){
                                            BestOFValue = AchievedFValue;
                                            for par in PS.getParameterSet(){
                                                var currvalue = par.getCurrentValue();
                                                par.setBestValue(currvalue);
                                            }
                                            writeln("--------------------------------FValue and Best ParameterSet have got Updated! \n");
                                        }
                                        for Machine in MachinesSingle{
                                            if (Machine.hostID == here.id){ 
                                                if (RunFailedSimulation == true) {
                                                    if (abs(BestOFValue) < abs(Machine.Fbest)){
                                                        Machine.Fbest = BestOFValue;
                                                        Machine.BestParSet = PS.getParameterSet();
                                                    }
                                                } else {
                                                    Machine.Fbest = BestOFValue;
                                                    Machine.BestParSet = PS.getParameterSet();
                                                }
                                                var MasterData: RowsForMasterTablesFunctionalSingle;
                                                MasterData.SimID = SimID;
                                                MasterData.IMWEBsEndTimeDate = IMWEBsSimulation.getEndTimeDate():string;
                                                MasterData.IMWEBsStartTimeDate = IMWEBsSimulation.getStartTimeDate():string;
                                                MasterData.IMWEBsSimulationRunTime = IMWEBsSimulation.getSimulationRunTime():string;
                                                MasterData.ParsetId = ParSetID;
                                                MasterData.ParmeterSet = PS;
                                                MasterData.PerformanceResult = PerformanceResults;
                                                var lock = Machine.WriteToMasterTables$.readFE();
                                                Machine.DataforMasterTables.append(MasterData);
                                                writef("--------------------------------Data for SimId %s has been added to the Master Node from Node: %s \n", SimID, here.hostname);
                                                Machine.WriteToMasterTables$.writeEF(true);
                                            }
                                        }
                                        var numcomss: int = 0;
                                        for Com in ComCpuInfo{
                                            if (Com.StartSimIDs != "0"){
                                                numcomss = numcomss+1;
                                            }
                                        }
                                        if (MasterTablesAvailable$.isFull == true && numcomss == MyRemoteLocales.size){
                                            on Locales[0]{
                                                FillMasterTablesSingleObjectiveSingle(CheckSRCCValues);
                                            }
                                        } else {
                                            writeln("--------------------------------Master tables have been called by another node!\n");

                                        }
                                    } else {
                                        for Failed in IamFailedList{
                                            if (Failed.HostID == here.id){
                                                Failed.Numfailed = Failed.Numfailed +1;
                                                Failed.SimID.append(SimID);
                                                Failed.ParID.append(ParSetID);
                                                writeln("--------------------------------Failed Information due to IMWEBs failure has been recorded!\n");
                                            }
                                        }

                                    }
                                }
                            } catch  {
                                for Failed in IamFailedList{
                                    if (Failed.HostID == here.id){
                                        Failed.Numfailed = Failed.Numfailed +1;
                                    }
                                }
                            }
                        }
                        for St in FinalStatus {
                            if (St.HostName == here.hostname){
                                St.ChangeStatus(true);
                            }
                        }
                    } 
                    if (CalibrationType == "Multi-Objective"){
                        
                        /* ------------------- Variable Declaration Step ------------------------- */
                        /* The next step is to read the assigned parameter set to this machine and set it to this object */
                        var PS = new shared ParameterSetInitialization(ProjectPath);
                        PS.setParameterSet(getParameterSet(here.id));
                        var UnChangedParameterSet: list(shared Parameter, parSafe=true) = getParameterSet(here.id);
                        var StopDDS: bool = false; // Start off with doing DDS for each of the objectives 
                        var BestOFValue: real = getFBestValue(here.id);
                        var objF: string; // The Variable Name 
                        var objS: list(string); // The Indicators for the variable 
                        var FinishedDDSVars: list(string); /* These are variables for which the DDS algorithm has been already carried out and their parameters are going to be constant for calibrating the rest of unfinished variables */ 
                        var ObjectiveRound: int;
                        var RepeatedN: int = 0; 
                        var MachinesBestF: list(real); 
                        var MachinesBestFChecked: bool = false; 
                        var variablename: string; // Variable Name of the Current Machine
                        var Indicators: list(string); // Indicator Name of the current Machine 
                        var Leftside: real;
                        var Rightside: real;
                        var StoppingCriterionValue: real; 
                        var crowdingDisDone: bool = false; // Crowding Distance has not been done --> So, it is false.
                        var CurSimID = 1:string;
                        var usedBeforeParSet: bool;
                        var RunFailedSimulation = false;
                        var hostImfailed: string;
                        var TotalFailedSimulationsRunBythisMachine: int; 
                        var checkVarExist: bool = false;
                        var StoppingCriterionList: list(real); /* The point is that we need to calculate the standard deviation at the end of each Simulation, then we need to get the standard deviation of 
                        the last 10 of them, and it should be stored in the MaxIHomogenity variable, if it is less than the specified stopping criterion we need to stop the simulation. The same goes with MRD values */
                        /*var ParetoFront = ParetoFrontMaster;  --> If you have a Reference Point for the Objective values --> Set this True, otherwise set it False! */
                        var VariablesNames: list(string) = MasterVariablesNames; 
                        var Objectives: list(string) = MasterObjectives; 
                       
                        if VariablesNames.size != 0{
                            var variString = VariablesNames[0];
                            for i in 1..VariablesNames.size-1{
                                variString = "/-/".join(variString,VariablesNames[i]);
                            }
                            writeln("----------------------------------------------------------------------------------------------------\n");
                            writeln("The AutoCalibration: Multi-VarIndicator Calibration");
                            writef("The AutoCalibration Variables are %s\n ", variString);
                            writeln("----------------------------------------------------------------------------------------------------\n");
                        }
                        var IndicatorNames: list(list(string)) = MasterIndicatorNames;
                        if IndicatorNames.size != 0 {
                            writeln("----------------------------------------------------------------------------------------------------\n");
                            writeln("The AutoCalibration: Multi-Indicator Calibration");
                            var varicounter = 0;
                            for Indicator in IndicatorNames{
                                var varicounter = 0; 
                                var indiString = Indicator[0];
                                for j in 1..Indicator.size-1 {
                                    indiString = "/-/".join(indiString, Indicator[j]);
                                    writef("The AutoCalibration Indicators are %s for Model Variable %s \n ", indiString, VariablesNames[varicounter]);
                                    writeln("----------------------------------------------------------------------------------------------------\n");
                                }
                                varicounter = varicounter + 1; 
                            }
                        }
                        if Objectives.size != 0 { 
                            writeln("----------------------------------------------------------------------------------------------------\n");
                            writeln("The AutoCalibration: Multi-Variable Calibration");
                            var variString = Objectives[0];
                            for x in 1..Objectives.size-1{
                                variString = "/-/".join(variString, Objectives[x]);
                            }
                            writef("The AutoCalibration Variables are %s \n ", variString);
                            writeln("----------------------------------------------------------------------------------------------------\n");
                        }
                        if (StoppingCriterionMethod == "FV-STD" || StoppingCriterionMethod == "CD-STD" ){
                            /* If we are working with STD, then the STD of all objectives for the last 10 simulations should be less than 0.05 to stop */
                            StoppingCriterionValue = 0.05; 
                        } else {
                            StoppingCriterionValue = 0; // If we are working with MDR, then the MRD value of the last 10 runs suoud be 0 to stop 
                        }
                        writeln("----------------------------------------------------------------------------------------------------\n");
                        writef("The Stopping Criterion is %s and has been initialized to %s \n ",StoppingCriterionMethod, StoppingCriterionValue:string) ;
                        writeln("----------------------------------------------------------------------------------------------------\n");
                        if (MeasureScope == "Speed"){  // How much speed would we have?
                            Leftside = 100; // 100 is a fake number
                            Rightside = StoppingCriterionValue;
                        }
                        if (MeasureScope == "Convergence"){// How much convergence would we have?
                            Leftside = SimControl;
                            Rightside = TotalSimulations + 1;
                        }
                        while (Leftside < Rightside){
                            try {  
                                var hostImfailed: string;
                                var readRepeat:bool = false;
                                var FialedMachineHostID: int = 0;
                                var FailedSimID: string = "0";
                                var FailedPar: string;
                                if (MeasureScope == "Speed") { /* This increase is due to the fact that we have not reached the Stopping Criterion and the Sim number is already reached */
                                    if (DDSCounterSimIDsimulator >= TotalSimulations){
                                        TotalSimulations = TotalSimulations + 2;
                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                        writef("The Number of Simulations on Node %s has been Increased!\n", here.hostname);
                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                    }
                                }  
                                if (MeasureScope == "Convergence"){ /* If the machine is taking over failed simulation, we need to increase its allocated simulation Number */
                                    if (TotalFailedSimulationsRunBythisMachine != 0){
                                        TotalSimulations = TotalSimulations + TotalFailedSimulationsRunBythisMachine;
                                        TotalFailedSimulationsRunBythisMachine = 0;
                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                        writef("Due to an IMWEBs failed run, the number of simulations on %s got incresed \n", here.hostname);
                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                        Rightside = TotalSimulations;
                                    }
                                }
                                if (Objectives.size == 0 && VariablesNames.size == 0 && IndicatorNames.size == 0){
                                    writeln("----------------------------------------------------------------------------------------------------\n");
                                    writeln("BeginPADDS Stage is over! The Second Stage is going to Start!\n");
                                    writeln("----------------------------------------------------------------------------------------------------\n");
                                    StopDDS = true; /* If we have run DDS for all the objectives, then Stop DDS. */
                                } 
                                for Failed in IamFailedList{
                                    if (Failed.Numfailed != 0){
                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                        writef("Working on a Failed Simulation on %s!\n", here.hostname);
                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                        var lock = readFaildList$.readFE();
                                        FialedMachineHostID = Failed.HostID;
                                        if (Failed.SimID.size != 0){
                                            FailedSimID = Failed.SimID.pop();
                                            FailedPar = Failed.ParID.pop();
                                        }
                                        Failed.Numfailed = Failed.Numfailed - 1;
                                        TotalFailedSimulationsRunBythisMachine = TotalFailedSimulationsRunBythisMachine + 1;
                                        readFaildList$.writeEF(true);
                                        break;
                                    }
                                }
                                if (FialedMachineHostID != 0) { /* Here we read one of machines is that need to be taken over, and set its status to false to inform other machines that this machine responsibility has been taken over*/
                                    RunFailedSimulation = true;
                                    if (FailedSimID == "0") { // If the machine which has been failed only has shared the ParameterSet it had
                                        PS.setParameterSet(getParameterSet(FialedMachineHostID));
                                        SimIDint = SimuID$.readFE(); // Read a new simulation ID
                                        SimuID$.writeEF(SimIDint + 1);
                                        PS.setSimulationID(SimIDint);
                                        for M in MachinesMulti{
                                            if (M.hostID == FialedMachineHostID){
                                                hostImfailed = M.hostName;
                                            }
                                            if (M.Fbest != 999) { // Read Best F value if it has 
                                                BestOFValue = M.Fbest;
                                            } else {
                                                BestOFValue = getFBestValue(here.id);
                                            }
                                        }
                                        ParSetID = "_".join(hostImfailed, SimIDint:string);
                                        PS.setParameterSet_ID(ParSetID);
                                        var SimIDstring = "".join(0:string, FialedMachineHostID:string, SimIDint:string);
                                        SimID = SimIDstring;
                                        
                                    } else { // If the failed Machine also has shared ParSet ID and Simulation ID 
                                        PS.setParameterSet(getParameterSet(FialedMachineHostID));
                                        PS.setParameterSet_ID(ParSetID);
                                        SimID = FailedSimID;
                                        ParSetID = FailedPar;
                                    }
                                    var Machineisthere: bool = false;
                                    for info in ComCpuInfo {
                                        if (info.UpdateComHostIDs == FialedMachineHostID){ /* If the Locale actually has failed in the first simulation and 
                                            the Computer table and CPU table have to wait for the info from this Computer --> We need to give the info and let the Master Node update these two tables  */
                                            if (info.TotalSimIDs != 0){
                                                Machineisthere = true;
                                                break;
                                            }
                                        }
                                    }
                                    if (Machineisthere == false){
                                        for Com in ComCpuInfo{
                                            if (Com.UpdateComHostIDs == FialedMachineHostID){
                                                Com.StartSimIDs = SimID;
                                                Com.TotalSimIDs = TotalSimulations;
                                            }
                                        }
                                        var numfinishedcoms: int = 0;
                                        for Com in ComCpuInfo{
                                            if (Com.StartSimIDs != "0"){
                                                numfinishedcoms = numfinishedcoms + 1;
                                                
                                            }
                                        }
                                        if (numfinishedcoms == MachinesSingle.size){
                                            on Locales[0]{
                                                updateComputerInfos();
                                            }
                                        }
                                        ComputerUpdateDone = true;
                                    }
                                }
                                else {
                                    /* The first stage of running PADDS is to run DDS individually for each of the variables and optimize them.
                                    Thus we have two stages --> 1) individual variables' optimization 2) All variables' optimization together
                                    On This program, the first stage is identified by a variable called StopDDS.
                                    If this variable is false it means that the first stage is currently going on and it should continue
                                    If this variable is True it means the second stage should start and continue till the end of the program. 
                                    */
                                    if (StopDDS == false){
                                        /* This for loop is for defining only the Variable (Objective) that the Machine should work on */
                                        for machine in MachinesMulti{
                                            if (machine.hostID == here.id) {
                                                /* How can we tell the machine when to switch to another variable? In fact, on the master node, when the TotalF is calculated for each variable 
                                                if the TotalF is not reached the threshold we had defined, then by using RepeatVariable variable the master node tells the machines to continue working on their current variable
                                                But, since we have machines with different speeds and the master node update could be after the first or second simulations for th variable, we need to 
                                                keep the machines working on their current variable for a while ( Does the optimum value get reached after the 2/3 simulations? No)
                                                So, we define even if the RepeatVariable is empty if the number of simulations for the current variable is less than 10, continue working on your current variable.
                                                */
                                                if (machine.RepeatVariable.size != 0){
                                                    checkVarExist = true;
                                                    readRepeat = true;
                                                    RepeatedN = RepeatedN + 1; 
                                                    if (machine.RepeatIndicator.size != 0){
                                                        Indicators = machine.RepeatIndicator;
                                                        objS = machine.RepeatIndicator;
                                                        machine.RepeatIndicator = new list(string);
                                                    }
                                                    objF = machine.RepeatVariable;
                                                    variablename = objF;
                                                    writeln("----------------------------------------------------------------------------------------------------\n");
                                                    writef("The Machine %s will be Working on a Repeated Objective (%s) for the BeginPADDS \n", here.hostname, objF);
                                                    writef("The so-far Number of Repeats for this objective on Machine %s is %s \n", here.hostname, RepeatedN:string);
                                                    writeln("----------------------------------------------------------------------------------------------------\n");
                                                } else if (RepeatedN > 0 && RepeatedN < 10) {
                                                    checkVarExist = true;
                                                    readRepeat = true;
                                                    RepeatedN = RepeatedN + 1;
                                                    variablename = objF;
                                                    writeln("----------------------------------------------------------------------------------------------------\n");
                                                    writef("The Machine %s will be Working on a Repeated Objective (%s) for the BeginPADDS (<10) \n", here.hostname, objF);
                                                    writef("The so far Number of Repeats for this objective on Machine %s is %s \n", here.hostname, RepeatedN:string);
                                                    writeln("----------------------------------------------------------------------------------------------------\n");
                                                } else if (readRepeat == false) {
                                                    checkVarExist = false;
                                                    if (RepeatedN != 0){
                                                        FinishedDDSVars.append(objF);
                                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                                        writeln("Finished DDS Variables are Getting Increased! \n");
                                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                                    } 
                                                    RepeatedN = 1;
                                                    if (Objectives.size != 0){
                                                        objF = Objectives[0];
                                                        Objectives.remove(objF);
                                                    } 
                                                    if (VariablesNames.size != 0){ 
                                                        objF = VariablesNames[0];
                                                        if (IndicatorNames.size != 0){
                                                            objS = IndicatorNames[0];
                                                            IndicatorNames.remove(objS);
                                                        }
                                                        VariablesNames.remove(objF);
                                                    }
                                                    variablename = objF;
                                                    Indicators = objS;
                                                    writeln("----------------------------------------------------------------------------------------------------\n");
                                                    writef("The Machine %s is Working on a new Objective (%s) for the BeginPADDS\n", here.hostname, objF);
                                                    writeln("----------------------------------------------------------------------------------------------------\n");
                                                }
                                            }
                                        } 
                                        /*  This If-else clause is for defining the best ParameterSet and its TotalF for the Variable (Objective) that the Machine should work on */
                                        /* Do we have a Best TotalF based on tehe Master Node? */
                                        /* First We set the Parameter Set and the Best F Value based on the Machine's own Parameter Set and FBest. Then, We try to see if we can improve it with the options we have
                                        The options are 1- The Fbests found on the other worker nodes, and 2- The F Best found on the Master Node */

                                        PS.setParameterSet(getParameterSet(here.id)); 
                                        BestOFValue = getFBestValue(here.id);
                                        /* Master Node Option */
                                        if (getArchiveParameterSet(here.id).size != 0){
                                            if (getArchiveFBestValue(here.id) < BestOFValue) {
                                                writeln("----------------------------------------------------------------------------------------------------\n");
                                                writef("%s will be working on the Best Solusion found based on the Master Node's Archive!\n", here.hostname);
                                                writeln("----------------------------------------------------------------------------------------------------\n");
                                                PS.setParameterSet(getArchiveParameterSet(here.id));
                                                BestOFValue = getArchiveFBestValue(here.id);
                                            }
                                        } 
                                        /* Worker Nodes Option */
                                        for machine in MachinesMulti{
                                            if (machine.DDSVariableName.startsWith(variablename) == true && machine.hostID != here.id && machine.Fbest != 999){  
                                                /* If we have a Machine Which has run DDS for an objective and has a FBest, we want  to know if the objective
                                                it has run is as same as objective this machine has run, then we want to compare teh Fbests and get the Min one */
                                                MachinesBestF.append(machine.Fbest);
                                                MachinesBestFChecked = true;
                                            } 
                                        }
                                        if (MachinesBestFChecked == true){ 
                                            /* If we have Machines with the same objective and they have F-best for that objective, do the comparison and get the min one */
                                            var MinFBest = min reduce(MachinesBestF);
                                            if (abs(MinFBest) < abs(BestOFValue)){
                                                writeln("----------------------------------------------------------------------------------------------------\n");
                                                writef("%s will be working on the Best Solusion found based on the Other Worker Nodes!\n", here.hostname);
                                                writeln("----------------------------------------------------------------------------------------------------\n");
                                                var updatedBestParSet: list(shared Parameter, parSafe=true);
                                                for machine in MachinesMulti{
                                                    if (machine.Fbest == MinFBest){
                                                        updatedBestParSet = machine.CurrentParameterSet;
                                                    }
                                                }
                                                BestOFValue = MinFBest;
                                                PS.setParameterSet(getParameterSet(here.id));
                                                for par in PS.getParameterSet(){
                                                    for para in updatedBestParSet{
                                                        if (par.getParName() == para.getParName()){
                                                            par.setCurrentValue(para.getCurrentValue());
                                                            par.setBestValue(para.getBestValue());
                                                        }
                                                    }
                                                }
                                            } 
                                            MachinesBestF.clear();
                                            MachinesBestFChecked = false;
                                        }
                                    } else {
                                        objF = "";
                                        objS = new list(string);
                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                        writef("The Machine %s is Working on a the Second Stage of the PADDS Algorithm \n", here.hostname);
                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                        /* If we have Not yet done the Crowding Distance, check to see if you have Crowding Distance Parset, and if yes , get it and start the simulation */
                                        if (crowdingDisDone == false){ 
                                            for M in MachinesMulti{
                                                if (M.hostID == here.id){
                                                    if (M.crowdingDistanceParSet.size != 0){
                                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                                        writef("%s is going to work on the Crowding Distance Solusion!\n", here.hostname);
                                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                                        PS.setParameterSet(M.crowdingDistanceParSet);
                                                        crowdingDisDone = true; // Set the Crowding Distance True 
                                                    }
                                                }
                                            }
                                        } else {
                                            PS.setParameterSet(getParameterSet(here.id));
                                            for M in MachinesMulti{
                                                if (M.hostID == here.id){
                                                    if (M.BestParSetArchive.size != 0){ 
                                                        /* Then, if we have a Current Parameter From the update of the Master Archive, get it and check the Dominance 
                                                        Between This Archive and the Worker Node's Current Archive */
                                                        var Solutions: list(list(string));
                                                        var IDs: list(real);
                                                        Solutions.append(M.MasterArchive);
                                                        IDs.append(1);
                                                        Solutions.append(M.CurrentArchive);
                                                        IDs.append(2);
                                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                                        writef("On %s, the Dominance check between Archive's Best Solution and the Machine's Current Solution is going to be done!\n", here.hostname);
                                                        writeln("----------------------------------------------------------------------------------------------------\n");

                                                        var BestID = ProgramDBClass.DominanceCheckAndFinalSolFind(Solutions,IDs); 
                                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                                        writef("On %s, the Dominance check between Archive's Best Solution and the Machine's Current Solution Result is %s\n", here.hostname, BestID:string);
                                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                                        if (BestID == 1){
                                                            writeln("----------------------------------------------------------------------------------------------------\n");
                                                            writef("On %s, Master Archive's Solusion won the Crowding Distance!\n", here.hostname);
                                                            writeln("----------------------------------------------------------------------------------------------------\n");
                                                            PS.setParameterSet(M.BestParSetArchive);
                                                        } else {
                                                            writeln("----------------------------------------------------------------------------------------------------\n");
                                                            writef("On %s, the Current Solusion won the Crowding Distance!\n", here.hostname);
                                                            writeln("----------------------------------------------------------------------------------------------------\n");
                                                            PS.setParameterSet(M.CurrentParameterSet);
                                                        }
                                                    } 
                                                }
                                            }
                                        }
                                    } 
                                    for Machine in MachinesMulti{
                                        if (Machine.hostID == here.id){ //Empty them
                                            Machine.DDSVariableName = objF;
                                            Machine.DDSIndicatorName = objS;
                                        }
                                    }
                                    /* Reading a new simulation ID */
                                    SimIDint = SimuID$.readFE(); 
                                    SimuID$.writeEF(SimIDint + 1);
                                    PS.setSimulationID(SimIDint);
                                    ParSetID = "_".join(here.hostname, SimIDint:string);
                                    PS.setParameterSet_ID(ParSetID);
                                    var SimIDstring = "".join(0:string, here.id:string, SimIDint:string);
                                    SimID = SimIDstring;
                                    if (ComputerUpdateDone ==  false) { // We need to update two Computers and CPU tables on the Master Node 
                                        for Com in ComCpuInfo{
                                            if (Com.UpdateComHostIDs == here.id){
                                                Com.StartSimIDs = SimID;
                                                Com.TotalSimIDs = TotalSimulations;
                                            }
                                        }
                                        var numfinishedcoms: int = 0;
                                        for Com in ComCpuInfo{
                                            if (Com.StartSimIDs != "0"){
                                                numfinishedcoms = numfinishedcoms + 1;
                                            }
                                        }
                                        if (numfinishedcoms == MachinesMulti.size){
                                            if (UpdateComputers$.isFull == true){
                                                var lock = UpdateComputers$.readFE();
                                                on Locales[0]{
                                                    updateComputerInfos();
                                                }
                                            }
                                        }
                                        ComputerUpdateDone = true; 
                                    }
                                }
                                try {
                                    var BeforeUpdate: list(shared Parameter, parSafe=true);
                                    var BeforeSimID: string;
                                    var Localarchive: list(string);
                                    DDSCounterSimIDsimulator = DDSCounterSimIDsimulator + 1;
                                    if (StopDDS == false){
                                        BeforeUpdate = PS.getParameterSet();
                                        BeforeSimID = CurSimID;
                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                        writeln("PADDS Functional Algorithm is being used at its First Stage (Individual Objectives' Optimization)!\n");
                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                        var DDSobject = new ParametersetUpdate(ProjectPath);
                                        /* Here, we are updating the ParameterSet that we have */ 
                                        if (FinishedDDSVars.size == 0) {
                                            PS.setParameterSet(DDSobject.FirstPADDS(PS.getParameterSet(),DDSCounterSimIDsimulator, EntireSimulationNumbers, objF));
                                        } else {
                                            var MergedParSet: list(shared Parameter, parSafe=true) = PS.getParameterSet();
                                            if (checkVarExist == false){
                                                for pars in UnChangedParameterSet{
                                                    if (pars.getAssociatedCalVar() == objF) {
                                                        MergedParSet.append(pars);
                                                    }
                                                }
                                            }
                                            PS.setParameterSet(DDSobject.NONFirstPADDS(MergedParSet,DDSCounterSimIDsimulator, EntireSimulationNumbers, objF, FinishedDDSVars));
                                        }
                                    } else if (StopDDS == true){ 
                                        BeforeUpdate= PS.getParameterSet();
                                        BeforeSimID = CurSimID;
                                        if (CalibrationAlgorithm == "SRCC-PADDS"){
                                            writeln("----------------------------------------------------------------------------------------------------\n");
                                            writeln("PADDS-SRCC Algorithm has started to be used!\n");
                                            writeln("----------------------------------------------------------------------------------------------------\n");
                                            if (hasSRCCValuesSet(here.id) == false){ 
                                                var SRCCobject = new ParametersetUpdate(ProjectPath);
                                                PS.setParameterSet(SRCCobject.DDSFunctional(PS.getParameterSet(),DDSCounterSimIDsimulator, EntireSimulationNumbers));
                                                CheckSRCCValues = true;
                                            } else if (hasSRCCValuesSet(here.id) == true){
                                                CheckSRCCValues = false;
                                                var SRCCobject = new ParametersetUpdate(ProjectPath);
                                                SRCCValues = getSRCCValues(here.id);
                                                PS.setParameterSet(SRCCobject.SRCCDDSFunctional(PS.getParameterSet(), SRCCValues));
                                            }
                                        } else if (CalibrationAlgorithm == "PADDS") { 
                                            writeln("----------------------------------------------------------------------------------------------------\n");
                                            writeln("PADDS Algorithm has started to be used!\n");
                                            writeln("----------------------------------------------------------------------------------------------------\n");
                                            var PADDSobject = new ParametersetUpdate(ProjectPath);
                                            PS.setParameterSet(PADDSobject.DDSFunctional(PS.getParameterSet(),DDSCounterSimIDsimulator, EntireSimulationNumbers));
                                        }
                                    }
                                    var IMWEBSsuccess = false;
                                    var IMWEBsSimulation = new IMWEBs(PS.getParameterSet(), ProjectName, ProjectPath);
                                    IMWEBSsuccess= IMWEBsSimulation.RunModel(HDF5Path, IMWEBsbashfilePath);
                                    if (IMWEBSsuccess == true){
                                        if (MeasureScope == "Convergence"){
                                            SimControl = SimControl + 1;
                                            Leftside = SimControl;
                                        }
                                        var PerformanceResults = ProgramDBClass.getSimulationPerformanceResultsMulti(SimID, ParSetID, SingleObjIndicatorName); 
                                        var TempFBest: real;
                                        if (StopDDS == false){
                                            if (objS.size == 0){
                                                var AllTotalFs = ProgramDBClass.getTotalF();
                                                for f in AllTotalFs{
                                                    writeln("----------------------------------------------------------------------------------------------------\n");
                                                    writef("TotalF is %s \n", f:string);
                                                    writeln("----------------------------------------------------------------------------------------------------\n");
                                                }
                                                for i in 0..AllTotalFs.size-1{
                                                    if (AllTotalFs[i] == objF){
                                                        TempFBest = AllTotalFs[i+1]:real;
                                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                                        writef("Local TotalF value on Machine %s has been found as %s\n", here.hostname, AllTotalFs[i+1]);
                                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                                    }
                                                }
                                                if (readRepeat == false){
                                                    writeln("----------------------------------------------------------------------------------------------------\n");
                                                    writef("Update Local Archive: The First Simulation for Objective %s on Machine %s\n", objF, here.hostname);
                                                    writeln("----------------------------------------------------------------------------------------------------\n");
                                                    var IndicNam: string;
                                                    ProgramDBClass.getLocalFValue(true);
                                                    ProgramDBClass.Archive_Update(PS, TempFBest, objF , IndicNam, true); /* Updating the Local Archive */
                                                    BestOFValue = ProgramDBClass.getBestF();
                                                    PS.setParameterSet(ProgramDBClass.getBestParArchive());
                                                    CurSimID = ProgramDBClass.getcurentSimID();
                                                } else {
                                                    if (abs(TempFBest) < abs(BestOFValue)){
                                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                                        writef("Update Local Archive: None-First Simulations for Objective %s on Machine %s\n", objF, here.hostname);
                                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                                        BestOFValue = TempFBest;
                                                        var IndicNam: string;
                                                        ProgramDBClass.getLocalFValue(true);
                                                        ProgramDBClass.Archive_Update(PS, TempFBest, objF , IndicNam, true); /* Updating the Local Archive */
                                                        CurSimID = ProgramDBClass.getcurentSimID();
                                                        usedBeforeParSet = false;
                                                    } else {
                                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                                        writef("No Update Occurred for the Local Archive on Machine %s\n", here.hostname);
                                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                                        PS.setParameterSet(BeforeUpdate);
                                                        usedBeforeParSet = true;
                                                        CurSimID = BeforeSimID;
                                                    }
                                                }
                                            } else {
                                                /* Not Checked */
                                                for indicator in objS {
                                                    ProgramDBClass.Archive_Update(PS, BestOFValue, objF, indicator, true);
                                                    if (ProgramDBClass.getBestF() < BestOFValue ){
                                                        BestOFValue = ProgramDBClass.getBestF();
                                                        PS.setParameterSet(ProgramDBClass.getBestParArchive());
                                                        CurSimID = ProgramDBClass.getcurentSimID();
                                                        usedBeforeParSet = false;
                                                    } else {
                                                        PS.setParameterSet(BeforeUpdate);
                                                        usedBeforeParSet = true;
                                                    }
                                                    
                                                }
                                            }
                                        } else {
                                            var IndicNam: string;
                                            var VarNam: string; 
                                            writeln("--------------------------------We are in PADDS Archive Upadte. BeginPADDS is over\n");
                                            writeln("--------------------------------\n");
                                            ProgramDBClass.getLocalFValue(true);
                                            ProgramDBClass.Archive_Update(PS, 99, VarNam, IndicNam, false);
                                            if (ProgramDBClass.getDominanceStatus() == "ADDED"){
                                                var CurSimIDNow = ProgramDBClass.getcurentSimID();
                                                PS.setParameterSet(ProgramDBClass.CrowdingDistance(ProgramDBClass.getBestParArchive(), MultiobjectiveType));
                                                Localarchive = ProgramDBClass.getanArchivebySimID(CurSimIDNow);
                                                var LocalArchiveString: string;
                                                writef("--------------------------------Current Simulation ID has got Changed! The previous one was %s and not it is %s\n",CurSimID, CurSimIDNow);
                                                writeln("--------------------------------\n");
                                                LocalArchiveString = Localarchive[0];
                                                for i in 1..Localarchive.size -1{
                                                    LocalArchiveString = "--".join(LocalArchiveString, Localarchive[i]);
                                                }
                                                writef("--------------------------------The Local Found Archive is %s\n",LocalArchiveString);
                                                writeln("--------------------------------\n");
                                                BestOFValue = ProgramDBClass.getBestF(); 
                                                CurSimID = CurSimIDNow;
                                                usedBeforeParSet = false;
                                            } else {
                                                writeln("--------------------------------Current Simulation ID has NOT been Changed!\n");
                                                writeln("--------------------------------\n");
                                                PS.setParameterSet(BeforeUpdate);
                                                CurSimID = BeforeSimID;
                                                Localarchive = ProgramDBClass.getanArchivebySimID(CurSimID); 
                                                var LocalArchiveString: string;
                                                LocalArchiveString = Localarchive[0];
                                                for i in 1..Localarchive.size -1 {
                                                    LocalArchiveString = "--".join(LocalArchiveString, Localarchive[i]);
                                                }
                                                writef("--------------------------------The Local Found Archive is %s\n",LocalArchiveString);
                                                writeln("--------------------------------\n");
                                                usedBeforeParSet = true;
                                            }
                                        } 
                                        /* Creating MasterData Record for the simulation which was run on this Machine to send it to the Master Node */
                                        var MasterData: RowsForMasterTablesFunctionalMulti;
                                        MasterData.SimID = SimID;
                                        MasterData.IMWEBsEndTimeDate = IMWEBsSimulation.getEndTimeDate();
                                        MasterData.IMWEBsStartTimeDate = IMWEBsSimulation.getStartTimeDate();
                                        MasterData.IMWEBsSimulationRunTime = IMWEBsSimulation.getSimulationRunTime(): string;
                                        MasterData.ParsetId = ParSetID;
                                        MasterData.ParmeterSet = PS;
                                        MasterData.TotalF = TempFBest;
                                        MasterData.VariableName = objF;
                                        MasterData.IndicatorName = objS;
                                        MasterData.PerformanceResult = PerformanceResults;

                                        if (RunFailedSimulation == true){
                                            if (StopDDS == false){
                                                for Machine in MachinesMulti{
                                                    if (Machine.hostID == FialedMachineHostID){ 
                                                        if (Machine.Fbest > BestOFValue){
                                                            Machine.Fbest = BestOFValue;
                                                            Machine.CurrentParameterSet = PS.getParameterSet();
                                                        }
                                                        if (readRepeat == false){
                                                            Machine.objectivesDone = Machine.objectivesDone + 1;
                                                        }
                                                        var lock = Machine.WriteToMasterTables$.readFE();
                                                        Machine.DataforMasterTables.append(MasterData);
                                                        Machine.WriteToMasterTables$.writeEF(true);
                                                    }
                                                }
                                            } else {
                                                for Machine in MachinesMulti{
                                                    if (Machine.hostID == FialedMachineHostID){ 
                                                        var SolutionsTobeChecked: list(list(string));
                                                        var Ids: list(real);
                                                        
                                                        SolutionsTobeChecked.append(Machine.CurrentArchive);
                                                        Ids.append(1);
                                                        SolutionsTobeChecked.append(Localarchive);
                                                        Ids.append(2);

                                                        var FinalID = ProgramDBClass.DominanceCheckAndFinalSolFind(SolutionsTobeChecked, Ids);
                                                        if (FinalID == 2){
                                                            writeln("----------------------------------------------------------------------------------------------------\n");
                                                            writeln("Machine's Local Archive won over the the Current Archive!\n");
                                                            writeln("----------------------------------------------------------------------------------------------------\n");
                                                            Machine.CurrentParameterSet = PS.getParameterSet();
                                                            Machine.CurrentArchive = Localarchive;
                                                        }

                                                        var lock = Machine.WriteToMasterTables$.readFE();
                                                        Machine.DataforMasterTables.append(MasterData);
                                                        Machine.WriteToMasterTables$.writeEF(true);
                                                    }
                                                }
                                            }
                                        } else {
                                            if (StopDDS == false){
                                                for Machine in MachinesMulti{
                                                    if (Machine.hostID == here.id){ 
                                                        if (Machine.Fbest > BestOFValue){
                                                            Machine.Fbest = BestOFValue; 
                                                            Machine.CurrentParameterSet = PS.getParameterSet();
                                                        }
                                                        var lock = Machine.WriteToMasterTables$.readFE();
                                                        Machine.DataforMasterTables.append(MasterData);
                                                        Machine.WriteToMasterTables$.writeEF(true);
                                                        if (readRepeat == false){
                                                            Machine.objectivesDone = Machine.objectivesDone + 1;
                                                        }
                                                    }
                                                }
                                            } else {
                                                for Machine in MachinesMulti{
                                                    if (Machine.hostID == here.id){ 
                                                        Machine.CurrentParameterSet = PS.getParameterSet();
                                                        Machine.CurrentArchive = Localarchive;
                                                        var lock = Machine.WriteToMasterTables$.readFE();
                                                        Machine.DataforMasterTables.append(MasterData);
                                                        Machine.WriteToMasterTables$.writeEF(true);
                                                    }
                                                }
                                            }
                                        }
                                        var numcomss: int = 0;
                                        for Com in ComCpuInfo{
                                            if (Com.StartSimIDs != "0"){
                                                numcomss = numcomss + 1;
                                            }
                                        }
                                        if (MasterTablesAvailable$.isFull == true && numcomss == MachinesMulti.size) {
                                            on Locales[0]{
                                                FillMasterTablesMultiObjective(CheckSRCCValues, StoppingCriterionMethod);
                                            }
                                        } else {
                                            writeln("----------------------------------------------------------------------------------------------------\n");
                                            writeln("Master Tables have been called by another node!\n");
                                            writeln("----------------------------------------------------------------------------------------------------\n");
                                        }
                                    } else {
                                        for Failed in IamFailedList{
                                            if (Failed.HostID == here.id){
                                                Failed.Numfailed = Failed.Numfailed +1;
                                                Failed.SimID.append(SimID);
                                                Failed.ParID.append(ParSetID);
                                                writeln("----------------------------------------------------------------------------------------------------\n");
                                                writeln("Failed Information due to IMWEBs failure has been recorded!\n");
                                                writeln("----------------------------------------------------------------------------------------------------\n");
                                            }
                                        }
                                    }
                                    if (MeasureScope == "Speed"){ // Each time that The master Node gets updated it calculated teh Stopping criterion, so we also need to get it and update teh current one on the machine 
                                        for M in MachinesMulti{
                                            Leftside = M.UpdatedStopingCriterionValue;
                                        }
                                    }
                                } catch {
                                    for Failed in IamFailedList{
                                        if (Failed.HostID == here.id){
                                            Failed.Numfailed = Failed.Numfailed +1;
                                            Failed.SimID.append(SimID);
                                            Failed.ParID.append(ParSetID);
                                            writeln("----------------------------------------------------------------------------------------------------\n");
                                            writeln("Failed Information has been recorded!\n");
                                            writeln("----------------------------------------------------------------------------------------------------\n");
                                        }
                                    }

                                }
                            } catch {
                                for Failed in IamFailedList{
                                    if (Failed.HostID == here.id){
                                        Failed.Numfailed = Failed.Numfailed +1;
                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                        writeln("Failed Information has been recorded!\n");
                                        writeln("----------------------------------------------------------------------------------------------------\n");
                                    }
                                }
                            }
                        }
                        for St in FinalStatus {
                            if (St.HostName == here.hostname){
                                St.ChangeStatus(true);
                            }
                        }
                    } 
                }
            }
            var Status = 0; 
            for Stread in FinalStatus {
                if (Stread.readCeaseVar() == true) {
                    Status = Status + 1 ;
                }
            }
            var MachineSize: int;
            if (MachinesSingle.size != 0){
                MachineSize = MachinesSingle.size;
            } else if (MachinesMulti.size != 0){
                MachineSize = MachinesMulti.size;
            }
            if (Status == MachineSize){
                proc getSpeedofCalibration(){ 
                    var TotalSpeed: real = 0;
                    if (MachinesSingle.size != 0){
                        for Machine in MachinesSingle{
                            var speed = PrDB.Computer_Performance_Info_Update(Machine.hostName, "Functional");
                            if (speed >= TotalSpeed) {
                                TotalSpeed = speed;
                            }
                        }
                    } else {
                        for Machine in MachinesMulti{
                            var speed = PrDB.Computer_Performance_Info_Update(Machine.hostName, "Functional");
                            if (speed >= TotalSpeed) {
                                TotalSpeed = speed;
                            }
                        }
                    }
                    CalibrationSpeed = TotalSpeed; 
                    writef("--------------------------------Total Model Simulations Execution Time is %s", CalibrationSpeed:string);
                }
                on Locales[0]{
                    getSpeedofCalibration();
                    here.chdir(CSVFilesPath);
                    rename("PhDProjectDatabase.db", "FinalDDSDatabase.db");
                }
            }
        }
    } 
}
