use List;
use Random;
use IO;
use FileSystem;
use Spawn;
use runIMWEBs;


/* This module is for 
        1- Initializing a parameter set at the beginning of the program (Using ParameterSetInitialization class) -->
        To do so, we need to have the path of EF core application. Then, by reading from the Parameters_seed table, it initializes Parameter Objects.
        2- Updating the parameter set from the second simulation, using the DDS algorithm (Using ParametersetUpdate class).
        3- Creating Parameter objects by Parameter Class (Using Parameter class).
    This Module mainly works with Parameters_Seed, ParameterSet_Info, and Computers_Info tables.
    It also has a few queries to the Simulation_Genral_Info table.*/ 
    
/* This record belongs to the SRCC-DDS algorithm, and it is for storing stable SRCC values and the Parameters' Calibration IDs */ 
class ParametersSRCCValues{
    var ParameterCalibrationID: int;
    var SRCCValue: real;
    proc init(id:int, value:real){
        this.ParameterCalibrationID = id;
        this.SRCCValue = value;
    }
}
class ParameterSetInitialization{
    /*
    This class is for initializing a parameterset object for starting the simulations with. 
    This class, in fact, returns a list of Parameter objects. 
    By querying the Computers_info, CPU_Info, Parameters_Seed and ParameterSet tables, this class figures out 
            1-what parameters do we have for the calibration?
            2- what are their attributes? and 
            3-what are the initial values for these parameters?
    The list that is returned by this calss will be passed to the first simulation on each computing unit. 
    This class input argument is only the path of the EF core Application folder.
    */
    /* We create a list of Parameter objects to fill their attributes and have a ParameterSet at the end */
    /* The Project Path is the Path of EF core Application, and It should be defined when initializing a parameter set. */
    var ProjectPath: string;
    // Each time, the Parameter set is associated with a Simulation ID. This ID is important since we use this ID to optimized the  parameter set in the DDS algorithm.
    var Simulation_ID: int;
    // Each time, the parameter set is associated with a Paramterset_ID. This ID is important to fill the ParameterSet and Simulation_Genral_Info tables.
    
    // We need to know if the values in the currentvalue attribute are Initial values or not. To check this We define a boolean variable called IsInitial. 
    var IsInitial = true;
    var hostname: string;
    var hostID: real;
    var Parameterset_ID: string;
    var ParSet: list(shared Parameter, parSafe=true);

    /* For the Functional parallelization Strategy, we need to create one this calss' objective for each worker and then, we need to work with it.
    But on the worker nodes, we do not have the "Parameters" tables. So, we need to have an initializer that only gives access to the class variables and functions. We use this initializer on eth worker nodes and mainly work
    with three functions  --> Set parameter Set 2- set Simulation ID 3- set Parameter set Id
    On the other hand, on the master node, we create an actual parameter set using the main initializer which defines exactly which parameters we have.
    Then, we get the parameter set and assign it to the worker nodes. 
    Worker nodes create an object of this class with the second initializer, and then they read the parameter set and assign it to the object and then they start playing with three mentioned functions  */
    proc init(EFProjectPath:string, initialize:bool, slmPath:string){

        this.ProjectPath = EFProjectPath;
        this.hostname = here.hostname;  
        this.hostID = here.id;
        
        /*
        We want to know which ParametersetID (among the seed Paramtersets) should be assigned to each computer. 
        I will be working with Multi-computer architecture for the Parallel DDS, and I should not do parallelization on each computer. 
        In addition, each computer starts with a different Parameter set from the rest of the computers. 
        However, these parameter sets should be close to each other in the parameter space to not "Intentionally" increase the global search ability of the algorithm, 
        which affects the quality of solutions. 
        Therefore, the Parameterset_Info table should be seed with parameter values, accordingly, before the start of the auto-calibration program. 
        In order to assign a diffrent paramter set to each computer, teh paramter set IDs shoudl be defiend in this format --> hostname_hostID
        */

        /*
        The first step is to get the ParamtersetID for each computer. To do so, by having the hostname and host ID of the computer,
        We query the Computers_Information and CPU_Info tables, just to make sure that we are using Multi-computer Architecture. If we are using Multi-core architecture,
        then the Parameterset assignment process would be different (Although I code for this part in EF core app, this would not be the case for the Parallel DDS algorithm).
        */
        var parameters: list(shared Parameter, parSafe=true);
        /*
        var Com_command = "dotnet run getInitialParameterSetID";
        var ComSELECT_input = " ".join(Com_command, hostname, hostID:string, "--project", ProjectPath);
        var ComSELECT = spawnshell(ComSELECT_input, stdout=PIPE);
        var Pline:string;
        var parid: string; 
        
        while ComSELECT.stdout.readline(Pline) {
            parid = Pline;
        }
        this.Parameterset_ID = parid;
        ComSELECT.wait();
        */
        /*
        After getting the ID of the initial Parameterset assigned to the computer, We need to initialize parameters in the parameter set with "their attribute".
        In order to do so, we need to query the Parameters_Seed table and initialize as many as parameters we have for the calibration and store all these parameters in a list,
        which will be identified as the "Paramter Set".
        */
        var command = "dotnet run SelectAllCalibrationParameters";
        var SubSELECT_input = " ".join(command, slmPath ,"--context Main_PhD_Project_Database","--project", ProjectPath);
        var SubSELECT = spawnshell(SubSELECT_input, stdout=PIPE);
        var line:string;
        while SubSELECT.stdout.readline(line) {
            var Par_Info_List: list(string);
            for i in line.split(","){
                for j in i.split(":"){
                    Par_Info_List.append(j);
                }
            }
            var Par = new shared Parameter();
            Par.setParName(Par_Info_List[1]);
            Par.setParameterID(Par_Info_List[5]: real);
            Par.setParametercalID(Par_Info_List[3]:int);
            Par.setAssociatedCalVar(Par_Info_List[7]);
            parameters.append(Par);
        }
        SubSELECT.wait();
        var commandtwo = "dotnet run SelectAllParameters";
        var SubSELECTtwo_input = " ".join(commandtwo, slmPath,"--project", ProjectPath);
        var SubSELECTtwo = spawnshell(SubSELECTtwo_input, stdout=PIPE);
        var Par_Info_List: list(string);
        while SubSELECTtwo.stdout.readline(line) {
            for i in line.split(","){
                for j in i.split(":"){
                    if (j.size != 0){
                        Par_Info_List.append(j);
                    }
                }
            }
        }
        SubSELECTtwo.wait();
        var i: int = 0;
        for i in 0..#(Par_Info_List.size- 3) {
            if (Par_Info_List[i+2] == "ParID"){
                var ID = Par_Info_List[i+3]: real;
                for par in parameters{
                    var Parref = par.getParameterID();
                    if Parref == ID {
                        if (Par_Info_List[i+4] == "ParameterType"){
                            par.setParameterType(Par_Info_List[i+5]);
                        }
                        if (Par_Info_List[i+6] == "ModuleID"){
                            par.setModuleID(Par_Info_List[i+7]);
                        }
                        if (Par_Info_List[i+8] == "UpperValue"){
                            par.setUpperValue(Par_Info_List[i+9]: real);
                        }
                        if (Par_Info_List[i+10] == "LowerValue"){
                            par.setLowerValue(Par_Info_List[i+11]: real);
                        }
                        if (Par_Info_List[i+12] == "ClassName"){
                            par.setClassName(Par_Info_List[i+13]);
                        }
                        if (Par_Info_List[i+14] == "ChangeType"){
                            if (Par_Info_List[i+15]!= "ParameterName" ||  Par_Info_List[i+15].isEmpty() != true){
                                par.setChangeType(Par_Info_List[i+15]);
                            } 
                        }
                        if (par.getChangeType().isEmpty() == true){
                            par.setChangeType("AC");
                        }
                        break;
                    }
                }

            }
        }
        this.ParSet = parameters;
    }
    /* For the functional Parallelization str, this initializer is only for the worker nodes */
    proc init(EFProjectPath:string){
        this.ProjectPath = EFProjectPath;
        this.hostname = here.hostname;  
        this.hostID = here.id;
    }

    /* Following are getter and setter methods for this class global variables */ 
    proc getParameterSet_ID(){
        return this.Parameterset_ID;
    }
    proc getProjectPath(){
        return this.EFProjectPath;
    }
    proc getHostID(){
        return this.hostID:int;
    }
    proc getProjectPath(){
        return this.EFProjectPath;
    }
    proc setParameterSet_ID(value:string){
        this.Parameterset_ID = value;
    }
    proc getProjectPath(){
        return this.ProjectPath;
    }
    proc addParameter(p: shared Parameter){
        this.ParSet.append(p);
    }
    proc CheckInitial(){
        return this.IsInitial;
    }
    proc changeInitial(value:bool){
        this.IsInitial=value;
    }
    proc getParameterSet(){
        return this.ParSet;
    }
    proc setParameterSet(pars: list(shared Parameter, parSafe=true)){
        this.ParSet = pars;
    }

    proc getSimulationID(){
        return this.Simulation_ID;
    }
    proc setSimulationID(value:int){
        this.Simulation_ID = value;
    }
    /* This function is for SA and it is used to get the parameter info from the parameters seed table */
    proc SAParameterInfo(parname: string, slmPath:string){

        var ParInfoSA: list(string);
        var command = "dotnet run SelectAllParameters_SA";
        var SubSELECTtwo_input = " ".join(command, slmPath, parname,"--project", ProjectPath);
        var SubSELECTtwo = spawnshell(SubSELECTtwo_input, stdout=PIPE);
        var Par_Info_List: list(string);
        var line:string;
        while SubSELECTtwo.stdout.readline(line) {
            for i in line.split(","){
                if (i.size != 0){
                    Par_Info_List.append(i);
                }
            }
        }
        SubSELECTtwo.wait();
        return Par_Info_List;
    }
}

/* The Following class is a  class that contains the methods for different optimization algorithms and any methods that these algorithms need to run */

class ParametersetUpdate{

    var ProjectPath: string;
    var Total_Number_Simulations: real;
    var hostname: string;
    var hostID: int;
    var STDVALS: list(string);
    var ObjectivesSRCC: int = 0;

    proc init(EFProjectPath: string){
        this.ProjectPath = EFProjectPath;
        this.hostname = here.hostname;  
        this.hostID = here.id;
        
    }
                                                                /* DDS Algorithm */
    
    /* This is DDS for Multi-Search --> It is not Complete */ 
    proc DDSMultiSearch(parameters: shared ParameterSetInitialization, SimuID: real){ 
        // This update function is for updating the current value of the Parameters based on DDS rules
        var totalSim: real = this.Total_Number_Simulations; //check
        var NumPars: real = parameters.getParameterSet().size; //Number of parameters 
        var probiter: real;
        if (totalSim != 0 ){
            probiter = 1-log(SimuID/log(totalSim)); //Calculate the perturbation probability for each simulation
        }
        var counter: int = 0; //The counter for number of parameters to perturb for each parameter set
        var rng = new RandomStream(real);
        for i in parameters.getParameterSet() do { //for loop to iterate over each parameter in teh X_test parameter set
            var N: real = rng.getNext(min= 0, max=1);//Generating a random normal number for each parameter
            var sigma: real = i.getUpperValue()-i.getLowerValue();
            if N < probiter {// if N less than P
                counter = counter + 1;
                var peturbv: real = 0.2*N*sigma;
                var NewValue: real = peturbv + i.getBestValue();
                if NewValue < i.getLowerValue() {
                    NewValue =  i.getLowerValue() + (i.getLowerValue() - NewValue);
                    if NewValue > i.getUpperValue() {
                        NewValue =  i.getLowerValue();
                    }
                }
                if NewValue > i.getUpperValue() {
                    NewValue =  i.getUpperValue() - (NewValue - i.getUpperValue());
                    if NewValue < i.getLowerValue() {
                        NewValue =  i.getUpperValue();
                    }
                } 
                i.setCurrentValue(NewValue);
                writeln(NewValue);
            }
        }
        if counter ==0 {
            var k: int = (floor(NumPars*rng.getNext(min= 0, max=1)));
            var N: real = rng.getNext(min= 0, max=1); //Generating a random normal number for each parameter
            var sigma: real = k.getUpperValue()-k.getLowerValue();
            var peturbv: real = 0.2*N*sigma;
            var NewValue: real = peturbv + k.getBestValue();
            if NewValue < k.getLowerValue() {
                NewValue =  k.getLowerValue();
            }
            if NewValue > k.getUpperValue() {
                NewValue =  k.getUpperValue();
            }
            k.setCurrentValue(NewValue);
        }
    }
    /*
    Usage: This is the DDS Function that runs for the Functional Str, since in the Functional Str, the worker nodes do not 
    have Computrs_info table, this Function get the total Number of simulations directly from eth program.
    Input: It gets a ParameterSetInitialization object and the total number of simulations 
    Output: It returns updated ParameterSetInitialization object for which Current value of the parameters have been updated with the DDS rules 
    Where this Function is used: One worker nodes, before IMWEBs run 
    C# functions: NONE*/
    
    proc DDSFunctional(parameters: list(shared Parameter, parSafe=true)){
        
        var rng = new RandomStream(real);
        var parameterSet: list(shared Parameter, parSafe=true) =  parameters;
        var BeforeChange: string;
        var UseRange: bool; 
        var P = rng.getNext(min= 0.4, max=1);
        for i in parameterSet{ 
            var N = rng.getNext(min= -1, max=1);
            if (abs(N) <= P){
                var sigma = i.getUpperValue()-i.getLowerValue();
                var peturbv = 0.2*sigma*N;
                if (i.getSTD() != 0 && i.getSTD() != 1 && abs(i.getSTD()) < 0.1){
                    peturbv = N * i.getRange() * 0.2;
                }
                var NewValue = peturbv + i.getBestValue();
                if NewValue < i.getLowerValue(){
                    NewValue =  i.getLowerValue() + (i.getLowerValue() - NewValue);
                    if NewValue > i.getUpperValue() {
                        NewValue =  i.getLowerValue();
                    }
                }
                if NewValue > i.getUpperValue(){
                    NewValue =  i.getUpperValue() - (NewValue - i.getUpperValue());
                    if NewValue < i.getLowerValue() {
                        NewValue =  i.getUpperValue();
                    }
                } 
                i.setCurrentValue(NewValue);
            }
        }
        if (UseRange == true){
            writeln("----------------------------------------------------------------------------------------------------\n");
            writeln("The DDS Algorithm is In the Local Search");
            writeln("----------------------------------------------------------------------------------------------------\n");
        }
        return parameterSet;
    }
    /* This Function is the SRCC-DDS Algorithm in which SRCC values are being used to define the chance of perturbation for a parameter */
    proc SRCCDDSFunctional(parameters: list(shared Parameter, parSafe=true), SRCCValues: list(shared ParametersSRCCValues), objFName:string){
        
        var parameterSet: list(shared Parameter, parSafe=true) = parameters;
        var rng = new RandomStream(real);
        var maxSRCC: real = -2;
        var minSRCC: real = 2;
        var MaxSRCCCalID: real;
        for SRCC in SRCCValues{
            if (abs(SRCC.SRCCValue) > maxSRCC){
                maxSRCC = SRCC.SRCCValue;
                //MaxSRCCCalID = SRCC.ParameterCalibrationID;
            }
            if (abs(SRCC.SRCCValue) < minSRCC){
                minSRCC = SRCC.SRCCValue;
            }
        }
        for i in parameterSet{ 
            var N = rng.getNext(min= 0, max=1);
            var SRCCVal: real = 0; 
            for SRCC in SRCCValues{
                if (SRCC.ParameterCalibrationID == i.getParametercalID()){
                    SRCCVal = SRCC.SRCCValue;
                }
            }
            if (abs(SRCCVal) >= 0.3){
                var N = rng.getNext(min= 0, max=1);
                var ObjSRCC: real;
                var YObjSRCC: real;
                if (objFName =="PBIAS"){
                    if (i.getPBIASSrcc() != 0){
                        ObjSRCC = i.getPBIASSrcc();
                        N = N * (i.getPBIASSrcc()/abs(i.getPBIASSrcc()));
                    }
                    YObjSRCC = i.getKGESrcc();
                } else {
                    if (i.getKGESrcc() != 0){
                        ObjSRCC = i.getKGESrcc();
                        N = N * (i.getKGESrcc()/abs(i.getKGESrcc()));
                    }
                    YObjSRCC = i.getPBIASSrcc();
                }
                if (abs(ObjSRCC) >= 0.3) {
                    var sigma = i.getUpperValue()-i.getLowerValue();
                    var peturbv = 0.2*sigma*N;
                    if (i.getUseRange() == 1){
                        var counter = 0;
                        if (YObjSRCC != 0){
                            if (YObjSRCC/abs(YObjSRCC) == ObjSRCC/abs(ObjSRCC)) {
                                if (abs(YObjSRCC) >= 0.4 ){
                                     N = N * (YObjSRCC /abs(YObjSRCC));
                                    peturbv = N*(i.getRange()*i.getSTD());
                                } else if (abs(ObjSRCC) >= 0.4){
                                    N = N * (ObjSRCC /abs(ObjSRCC));
                                    peturbv = N*(i.getRange()*i.getSTD());
                                }
                            } else {
                                peturbv = 0;
                            }
                        } 
                        writeln("The DDS Algorithm is In the Local Search");
                        writeln("----------------------------------------------------------------------------------------------------\n");
                    }
                    var NewValue = peturbv + i.getBestValue();
                    if NewValue < i.getLowerValue(){
                        NewValue =  i.getLowerValue() + (i.getLowerValue() - NewValue);
                        if NewValue > i.getUpperValue() {
                            NewValue =  i.getLowerValue();
                        }
                    }
                    if NewValue > i.getUpperValue(){
                        NewValue =  i.getUpperValue() - (NewValue - i.getUpperValue());
                        if NewValue < i.getLowerValue() {
                            NewValue =  i.getUpperValue();
                        }
                    } 
                    i.setCurrentValue(NewValue);
                }
            }
        }
        /*
        if (counter == 0) {
            var N: real = rng.getNext(min= 0, max=1); 
            for p in parameterSet{
                if (p.getParametercalID() == MaxSRCCCalID){
                    var sigma: real = p.getUpperValue() - p.getLowerValue();
                    var peturbv: real = 0.2*N*sigma;
                    var NewValue: real = peturbv + p.getBestValue();
                    if NewValue < p.getLowerValue() {
                        NewValue =  p.getLowerValue() + (p.getLowerValue() - NewValue);
                        if NewValue > p.getUpperValue() {
                            NewValue =  p.getLowerValue();
                        }
                    }
                    if NewValue > p.getUpperValue() {
                        NewValue =  p.getUpperValue() - (NewValue - p.getUpperValue());
                        if NewValue < p.getLowerValue() {
                            NewValue =  p.getUpperValue();
                        }
                    } 
                    p.setCurrentValue(NewValue);

                }
            }
        }
        */
        return parameterSet;
    } 

    /* This PADDS Algorithm is going to be used for Calibration  of the FIRST objective of a Multi-objective Calibration */
    proc FirstPADDS(parameters: list(shared Parameter, parSafe=true), Calvariable: string){
        
        var rng = new RandomStream(real);
        var UseRange: bool; 
        var parameterSet: list(shared Parameter, parSafe=true);
        for pars in parameters{
            if pars.getAssociatedCalVar().startsWith(Calvariable) {
                parameterSet.append(pars);
            }
        }
        for i in parameterSet{ 
            var N = rng.getNext(min= -1, max=1);
            var sigma = i.getUpperValue()-i.getLowerValue();
            var peturbv = 0.2*sigma*N;
            if (i.getUseRange() == 1){
                UseRange = true;
                peturbv = N * (i.getRange()*i.getSTD());
            }
            var NewValue = peturbv + i.getBestValue();
            if NewValue < i.getLowerValue(){
                NewValue =  i.getLowerValue() + (i.getLowerValue() - NewValue);
                if NewValue > i.getUpperValue() {
                    NewValue =  i.getLowerValue();
                }
                
            }
            if NewValue > i.getUpperValue(){
                NewValue =  i.getUpperValue() - (NewValue - i.getUpperValue());
                if NewValue < i.getLowerValue() {
                    NewValue =  i.getUpperValue();
                }
            } 
            i.setCurrentValue(NewValue);
        }
        if (UseRange == true){
            writeln("----------------------------------------------------------------------------------------------------\n");
            writeln("The DDS Algorithm is In the Local Search");
            writeln("----------------------------------------------------------------------------------------------------\n");
        }
        return parameterSet;
    }
    /* This PADDS Algorithm is going to be used for Calibration  of the NON-FIRST objectives of a Multi-objective Calibration */
    
    proc NONFirstPADDS(parameters: list(shared Parameter, parSafe=true), Calvariable: string, ConstCalvariable: list(string)){
        
        var parameterSet = FirstPADDS(parameters, Calvariable);
        for pars in parameters {
            for Const in ConstCalvariable{
                if pars.getAssociatedCalVar().startsWith(Const){
                    parameterSet.append(pars);
                }
            }
        }
        return parameterSet;
    }


                                                        /* Island-Based Multi-objective Parallelization */



    /* The following methods are for SRCC-DDS algorithm
    The idea for this algorithm is that we have only one machine on our cluster that calculates the SRCC values and checks their stability -->? One of the islands is the manager for SRCC 
    When SRCC achieved an STD of less than 5%, they are stable, and the manager sends them to the Worker Islands.

    The other machines run simulations and a pack of info which consists of 
    (SIMID, FValue, Parameter Calibration IDs and parameter values) will be sent to the Manager Machine from the Worker Machines when the SRCC frequency exchange threshold got satisfied 
    (we set this threshold and should be based on reducing the communication overhead). 
    Then, after each simulation, by the simulation ID and the exchanged data (if available), the manager calculates SRCC values and checks if they are stable. 
    Before they get stable, we use the DDS algorithm to update the parameter set, 
    but as soon as the SRCC values got stable, we use the SRCC-DDS algorithm instead, in which we used the SRCC values as the probability of selecting a parameter to perturb. 
    1- SRCCStableValue gets a simID, exchanged Data and the frequency to calculate the SRCC values and check their Stability. If they are stable it returns the 
    SRCC values --> Its return type is a list of records, each of which contains the parameter calibration ID and SRCC value 
    This function only runs on the Manager Node */

    /*
    Usage: As I mentioned, SRCC values are calculated on the manager node. We have an SRCC Frequency, which is literally the number of simulations after which the worker 
    nodes should send their Findings to the Manager which will be used by it to calculate SRCC values.
    So, this function is run on the worker node which actually gets the last frequency number of simulations and returns their info as a list of strings.
    Input: The SRCC Frequency, and the last sim ID, plus project name 
    Output: A list of strings which are Simulations Info required for calculating SRCC values
    Where this Function is used: On worker Islands just 
    C# functions: getExchangeSRCCValues function  --> Simulation_Performance_Info, Performance_Indicators_Seed, Simulation_General_Info, and ParameterSet tables 
    */
    proc SRCCShareResults(SimID: string, frequency:real, ProjectName:string){

        var command = "dotnet run getSRCCExchangeData/Worker";
        var SRCC_input = " ".join(command, SimID:string , ProjectName, frequency:string, "--project", ProjectPath);
        var SRCC = spawnshell(SRCC_input, stdout=PIPE);
        var Pline: string;
        var ExchangeListData: list(string);
        while SRCC.stdout.readline(Pline) {
            for i in Pline.split(","){
                ExchangeListData.append(i);
            }
        }
        SRCC.wait();
        return ExchangeListData;
    }
    /*
    Usage: On the Manager Island, if we have Exchange Data --> We need to use this function which gets the Exchange data, calculates SRCC values, updates
    associated table, checks the stability and it is stable, it returns SRCC values 
    Input: Exchange Data, Sim id and Frequency 
    Output: A list of SRCC values --> lsit of ParametersSRCCValues elements 
    Where this Function is used: On the Manager Island only 
    C# functions: SRCCTableUpdate, ReadExchangeSRCCData, calculateSRCCvalues functions  --> 
    Optimization_General_Info, SRCCTable,  Simulation_Performance_Info, Performance_Indicators_Seed, Simulation_General_Info, and ParameterSet tables 
    */
    proc SRCCStableValueWithExcahngeData(ExchangeData: list(string), SimID: string, frequency:real, ProjectName:string){

        var command = "dotnet run UpdateSRCCValues/Manager";
        var SRCCExdata = ExchangeData[0];
        for i in 1..#(ExchangeData.size - 1){
            SRCCExdata =",".join(SRCCExdata, ExchangeData[i]);
        }
        var SRCC_input = " ".join(command, SimID:string , ProjectName, frequency:string, SRCCExdata, "--project", ProjectPath);
        var SRCC = spawnshell(SRCC_input, stdout=PIPE);
        var Pline:string;
        var SRCCValues: list(ParametersSRCCValues);
        while SRCC.stdout.readline(Pline) {
            if (Pline.isEmpty() == true){
                break;
            } 
            else {
                var SRCC_List: list(string);
                for i in Pline.split(","){
                    for j in i.split(":"){
                        SRCC_List.append(j);
                    }
                }
                for i in 0..#((SRCC_List.size / 2) - 1){
                    SRCCValues.append(new ParametersSRCCValues(SRCC_List[2*i]:real, SRCC_List[(2*i)+1]:real));
                }
            }
        }
        SRCC.wait();
        return SRCCValues;
    }
                                /* -----------------------------------Functional- and Island-based Strategy ------------------- */

    /*
    For functional strategy we don't have Manger and workers or Exchange data, all the SRCC values are calculated on the master node,
    In this case, we use the following function

    Note- For the single objective Calibration --> we throw the name of the indicator we want
            For the multi-objective Calibration --> It calculates SRCC for all the objectives separately and then for each parameter it selects the maximum value of SRCC values obtained from all the objectives 
    */
    proc SRCCStableValue(SimID: string, ProjectName:string, Indicatorname:string, slrmpath:string){

        var command = "dotnet run UpdateSRCCValues/Manager";
        var SRCC_input: string;
        if (Indicatorname == "TotalF" || Indicatorname == "ALL"){
            SRCC_input = " ".join(command, SimID , ProjectName, slrmpath, "--project", ProjectPath);
        } else {
            SRCC_input = " ".join(command, SimID , ProjectName, slrmpath, Indicatorname, "--project", ProjectPath);
        }
        var SRCC = spawnshell(SRCC_input, stdout=PIPE);
        var Pline: string;
        var STDValues: list(string);
        var SRCCValues: list(shared ParametersSRCCValues);
        while SRCC.stdout.readline(Pline) {
            if (Pline.numBytes > 1){ 
                if (Pline.startsWith("STDS") == true){
                    var tmp: list(string);
                    for i in Pline.split(":"){
                        tmp.append(i);
                    } 
                    for i in 1..tmp.size-1 {
                        STDValues.append(tmp[i]);
                    }
                } 
                else {
                    for i in Pline.split(","){
                        var temp: list(string);
                        for j in i.split(":"){
                            temp.append(j);
                        }
                        var SRCCEnt = new shared ParametersSRCCValues(temp[0]: int, temp[1]: real);
                        SRCCValues.append(SRCCEnt);
                    }
                } 
            }
        }
        if (STDValues.size != 0){
            setSTDValues(STDValues);
        }
        SRCC.wait();
        return SRCCValues;
    }

    proc ObjFSRCCValue(parameters:list(shared Parameter, parSafe=true), slrmpath:string, simid:string){

        var command = "dotnet run ObjSRCCValuesSingle";
        var SRCC_input = " ".join(command, slrmpath, simid, "--project", ProjectPath);
        var SRCC = spawnshell(SRCC_input, stdout=PIPE);
        var Pline: string;
        while SRCC.stdout.readline(Pline) {
            if (Pline.size != 0){
                if (Pline.numBytes > 1){ 
                    for i in Pline.split(","){

                        var temp: list(string);
                        for j in i.split(":"){
                            temp.append(j);
                        }
                        for par in parameters {
                            if (par.getParametercalID() == temp[0]:int){
                                par.setKGESrcc(temp[2]:real);
                                par.setPBIASSrcc(temp[1]:real);
                                setObjectivesSRCC(1);
                            }
                        }
                    }
                } 
            }
        }
        SRCC.wait();
        return parameters;
    }

    proc setSTDValues(Values: list(string)){
        this.STDVALS = Values;
    }
    proc getSTDValues(){
        return this.STDVALS;
    }
    proc setObjectivesSRCC(value:int){
        this.ObjectivesSRCC = value;
    }
    proc getObjectivesSRCC(){
        return this.ObjectivesSRCC;
    }
}

class Parameter {


    var TableName: string;
    var ParameterID: real;
    var ParametercalID: int;
    var LocationID: real;
    var LocationFieldName: string;
    var ParameterType: string;
    var ClassName: string;
    var ModuleID: string;
    var ParName: string;
    var UpperValue: real;
    var LowerValue: real;
    var ChangeType: string;
    var CurrentValue: real;
    var BestValue: real;
    var STD: real;
    var Range: real;
    var UseRange: int;
    var AssociatedCalVar: string;
    var PBIASSrcc: real;
    var KGESrcc: real;

    proc init(){
    }

    proc init(tablename:string, calvariable:string, parname:string, parid:real, parcalid:real, locationid:real, locationfieldname:string, parametertype:string, moduleID:string, classname:string, upperval:real, lowerval:real, chnagetype:string){
        this.TableName = tablename;
        this.ParameterID = parid;
        this.ParametercalID = parcalid;
        this.LocationID = locationid;
        this.LocationFieldName = locationfieldname;
        this.ParameterType = parametertype;
        this.ClassName = classname;
        this.ModuleID = moduleID;
        this.ParName = parname;
        this.UpperValue =upperval;
        this.LowerValue = lowerval;
        this.ChangeType = chnagetype; 
        this.AssociatedCalVar = calvariable;
    }
    /* Following methods are getter and setter methods for the global parameters we have in this class */
    proc setBestValue(value:real){
        this.BestValue = value;
    }  
    proc getBestValue(){
        return this.BestValue;
    }
    proc setSTD(value:real){
        this.STD = value;
    }  
    proc getSTD(){
        return this.STD;
    }
    proc setRange(value:real){
        this.Range = value;
    }  
    proc getRange(){
        return this.Range;
    }
    proc setAssociatedCalVar(value:string){
        this.AssociatedCalVar = value;
    }  
    proc getAssociatedCalVar(){
        return this.AssociatedCalVar;
    }
    proc setCurrentValue(value:real){
        this.CurrentValue = value;
    }  
    proc getCurrentValue(){
        return this.CurrentValue;
    }
    proc getCalibrationText(){
        var text: string;
        if (getChangeType().size != 0){
            text = " | ".join(getClassName(), getModuleID(), getParName(), getCurrentValue():string, getChangeType());
        } else {
            text = " | ".join(getClassName(), getModuleID(), getParName(), getCurrentValue():string, "AC");
        }
        return text;
    }
    proc isParameterSame (p: shared Parameter){
        if (this.TableName == p.getTableName() && this.ParName == p.getParName() && this.ModuleID == p.getModuleID()){
            return true;
        } else {
            return false;
        }
    }
    proc setTableName(value:string){
        this.TableName = value;
    }
    proc getTableName(){
        return this.TableName;
    }
    proc setParameterType(value:string){
        this.ParameterType= value;
    }    
    proc getParameterType(){
        return this.ParameterType;
    }
    proc setClassName(value:string){
        this.ClassName = value;
    }    
    proc getClassName(){
        return this.ClassName;
    }
    proc setLocationFieldName(value:string){
        this.LocationFieldName = value;
    }    
    proc getLocationFieldName(){
        return this.LocationFieldName;
    }
    proc setParameterID(value:real){
        this.ParameterID = value;
    }    
    proc getParameterID(){
        return this.ParameterID;
    }
    proc setParametercalID(value:int){
        this.ParametercalID = value;
    }    
    proc getParametercalID(){
        return this.ParametercalID;
    }

    proc setPBIASSrcc(value:real){
        this.PBIASSrcc = value;
    }    
    proc getPBIASSrcc(){
        return this.PBIASSrcc;
    }
    proc setKGESrcc(value:real){
        this.KGESrcc= value;
    }    
    proc getKGESrcc(){
        return this.KGESrcc;
    }

    proc setLocationID(value:real){
        this.LocationID = value;
    }    
    proc getLocationID(){
        return this.LocationID;
    }
    proc setParName(value:string){
        this.ParName = value;
    }    
    proc getParName(){
        return this.ParName;
    }
    proc setUseRange(value:int){
        this.UseRange = value;
    }    
    proc getUseRange(){
        return this.UseRange;
    }
    proc setModuleID(value:string){
        this.ModuleID = value;
    }    
    proc getModuleID(){
        return this.ModuleID;
    }
    proc setUpperValue(value:real){
        this.UpperValue = value;
    }    
    proc getUpperValue(){
        return this.UpperValue;
    }
    proc setLowerValue(value:real){
        this.LowerValue = value;
    }    
    proc getLowerValue(){
        return this.LowerValue;
    }
    proc setChangeType(value:string){
        this.ChangeType = value;
    }    
    proc getChangeType(){
        return this.ChangeType;
    }
    proc getParFullName(){
        var text = "_".join(this.TableName, this.ModuleID, this.ParName);
        return text;
    }
}

