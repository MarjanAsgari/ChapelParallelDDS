use FileSystem;
use IO;
use List;
use Spawn;
use ProgramDatabase;

                    /* Fill all the Variables Below */ 
// CalibrationParameters.csv file --> [ParIDs, ParName]
// SimulationSummaries.csv file -->  [SummaryID, Summary Type] 
// MeasurementLookup.csv --> [Variable Name, MeasurementID, SimulationID, LocationType, StationWeight,IMWEBsFieldID, IMWEBsField]
// ProjectModelVariable.csv --> [Varibalename, Unit,  Measurement Table, Number Stations]
// PerformanceIndicator.csv --> [Varibale Name, Indicator name, Maxlimit, MinLimit, Weight] 
// ParetoFront.csv --> [ReferenceID, VariableName , TotalF, IndicatorName, IndicatorValue ] 
// NOTE: CSV files with one line cannot be read by Chapel. Leave the first Line Blank.
// NOTE: For Multi objective Calibration, "Multi" is added to the beginning of the Files'names 


class ManualTablesFill{

    var ParallelizationStr: string;
    var CalibrationType: string;
    var ProjectName: string;
    var MultiObjType: string;
    var calibrationAlgorithm: string;
    var MeasureScope: string;
    var StoppingCri: string;
    var StopValue: string; 
    var BoundArchive: string;
    var NumArchiveEle: int;
    var EFProjectPath: string;
    var BaseProjectPath: string;
    var IMWEBsPath: string;
    var ScenID: int;
    var CSVfilesPath: string;
    var SlurmTMP:string;


    proc init(ParStr:string, CalType:string, Projectname:string, MultiType: string, CalAlgo:string, MeasureS:string, StopCr:string, StopV:string, BoundArch: string, NumArchEle:int, EFpro:string, Basepro:string, Imwebs:string, scenid: int, csvs:string, slmtmp:string){
        this.ParallelizationStr = ParStr;
        this.CalibrationType = CalType;
        this.ProjectName = Projectname;
        this.MultiObjType = MultiType;
        this.calibrationAlgorithm = CalAlgo;
        this.MeasureScope = MeasureS;
        this.StoppingCri = StopCr;
        this.StopValue = StopV;
        this.BoundArchive = BoundArch;
        this.NumArchiveEle = NumArchEle;
        this.EFProjectPath = EFpro;
        this.BaseProjectPath = Imwebs;
        this.IMWEBsPath = Basepro;
        this.ScenID = scenid;
        this.CSVfilesPath = csvs;
        this.SlurmTMP = slmtmp;
    }
    proc FillTables(){
        if (ParallelizationStr == "Functional"){
            for loc in Locales do {
                on loc do{
                    var IndicatorValues: list(list(string));
                    var VariableNames: string;
                    var IndicatorNames: list(string); 
                    var IndicatorMaxlimits: list(string);
                    var IndicatorMinlimits: list(string);
                    var IndicatorsWeights: list(string); 
                    var VariablesUnits: string; 
                    var VariablesMeasureTables: string ; 
                    var VariablesNumStations: int; 
                    var StationsMeasureIDs: list(string); 
                    var StationsSimuIDs: list(string); 
                    var LocationTypes: list(string); 
                    var StationWeights: list(string); 
                    var IMWEBsField: string; 
                    var IMWEBsFieldID: string; 
                    var ParameterIDs: list(string);
                    var ParNames: list(string);
                    var ParAssoVar: list(string);
                    var TableAliasLists: list(list(string));
                    var SummaryTypes: list(string);
                    var TotalF: list(string);

                    proc OptimizationGeneralInfoTableSingleObjectiveFunc(){
            
                        var command = "dotnet run InsertOptimizationSingle";
                        var input = " ".join(command, ProjectName, ParallelizationStr, CalibrationType, calibrationAlgorithm, MeasureScope, StoppingCri, StopValue, BoundArchive, NumArchiveEle:string,SlurmTMP, "--project", EFProjectPath);
                        var Spawncommand = spawnshell(input);
                        Spawncommand.wait();
                    } 
                    proc OptimizationGeneralInfoTableMultiObjectiveFunc(){
                        var command = "dotnet run InsertOptimizationMulti";
                        var input = " ".join(command, ProjectName, ParallelizationStr, CalibrationType, MultiObjType, calibrationAlgorithm, MeasureScope, StoppingCri, StopValue, BoundArchive:string, NumArchiveEle:string, SlurmTMP, "--project", EFProjectPath);
                        var Spawncommand = spawnshell(input);
                        Spawncommand.wait();
                    }     
                    proc BaseProjectFill(){
                        
                        var command = "dotnet run BaseProjectFill";
                        var input = " ".join(command, ProjectName, BaseProjectPath, ScenID:string, SlurmTMP, "--project", EFProjectPath);
                        var Spawncommand = spawnshell(input);
                        Spawncommand.wait();
                    }
                    proc PerformanceIndicatorFillSingle(){
                        
                        var IndictorNamesString = IndicatorNames[0];
                        var IndicatorMaxlimitsString = IndicatorMaxlimits[0];
                        var IndicatorMinlimitsString = IndicatorMinlimits[0];
                        var IndicatorsWeightsString = IndicatorsWeights[0];
                        var n = IndicatorNames.size -1; 
                        for i in 1..n {
                            IndictorNamesString  = ",".join(IndictorNamesString, IndicatorNames[i]);
                            IndicatorMaxlimitsString   = ",".join(IndicatorMaxlimitsString , IndicatorMaxlimits[i]);
                            IndicatorMinlimitsString = ",".join(IndicatorMinlimitsString, IndicatorMinlimits[i]);
                            IndicatorsWeightsString = ",".join(IndicatorsWeightsString, IndicatorsWeights[i]);
                        }
                        var command = "dotnet run InsertIntoPerformanceIndicSingle";
                        var input = " ".join(command, VariableNames, IndictorNamesString, IndicatorMaxlimitsString, IndicatorMinlimitsString, IndicatorsWeightsString, SlurmTMP, "--project", EFProjectPath);
                        var Spawncommand = spawnshell(input);
                        Spawncommand.wait();
                    }
                    proc ProjectModelVariableFillSingle(){

                        var command = "dotnet run InsertIntoProjectVarSingle";
                        var input = " ".join(command, VariableNames, ProjectName, VariablesUnits, VariablesMeasureTables, VariablesNumStations:string, SlurmTMP, "--project", EFProjectPath);
                        var Spawncommand = spawnshell(input);
                        Spawncommand.wait();
                    }
                    proc MeasurementLookupFillSingle(){
                        var MeasIDs = StationsMeasureIDs[0];
                        var SimuIDs = StationsSimuIDs[0];
                        var LocationTypesString = LocationTypes[0];
                        var StationWeightsString = StationWeights[0];
                        var n = StationsMeasureIDs.size -1; 
                        for i in 1..n {
                            MeasIDs = ",".join(MeasIDs, StationsMeasureIDs[i]);
                            SimuIDs  = ",".join(SimuIDs, StationsSimuIDs[i]);
                            LocationTypesString = ",".join(LocationTypesString, LocationTypes[i]);
                            StationWeightsString = ",".join(StationWeightsString, StationWeights[i]);
                        } 
                        var command = "dotnet run InsertIntoMeasureLookupSingle";
                        var input = " ".join(command, VariableNames, MeasIDs, SimuIDs, LocationTypesString, StationWeightsString, IMWEBsField, IMWEBsFieldID, SlurmTMP, "--project", EFProjectPath);
                        var Spawncommand = spawnshell(input);
                        Spawncommand.wait();
                    }
                    proc InsertIMWEBsProgramTable(){
                        var Command = "dotnet run InsertImwebsProgram";
                        var Input = " ".join(Command, IMWEBsPath,"imwebsmain", SlurmTMP, "--project", EFProjectPath);
                        var Spcommand = spawnshell(Input);
                        Spcommand.wait();
                    }
                    if (CalibrationType == "Single-Objective"){
                        BaseProjectFill();
                        InsertIMWEBsProgramTable();
                        OptimizationGeneralInfoTableSingleObjectiveFunc();
                        /*Reading Performance Indicators File */
                        var PInd = open("/".join(CSVfilesPath,"PerformanceIndicator.csv"), iomode.r);
                        var PIndChannel = PInd.reader();
                        var line: string; 
                        while PIndChannel.readln(line) {
                            var Temp: list(string);
                            for i in line.split(","){
                                Temp.append(i);
                            }
                            VariableNames = Temp[0];
                            IndicatorNames.append(Temp[1]);
                            IndicatorMaxlimits.append(Temp[2]);
                            IndicatorMinlimits.append(Temp[3]);
                            IndicatorsWeights.append(Temp[4]);
                        }
                        PInd.close();
                        /*Reading Measurement Lookup File */
                        var MLnd = open("/".join(CSVfilesPath,"MeasurementLookup.csv"), iomode.r);
                        var MLndChannel = MLnd.reader();
                        while MLndChannel.readln(line) {
                            var Temp: list(string);
                            for i in line.split(","){
                                Temp.append(i);
                            }
                            VariableNames = Temp[0];
                            StationsMeasureIDs.append(Temp[1]);
                            StationsSimuIDs.append(Temp[2]);
                            LocationTypes.append(Temp[3]);
                            StationWeights.append(Temp[4]);
                            IMWEBsFieldID = Temp[5];
                            IMWEBsField = Temp[6];
                        }
                        MLnd.close();
                        /*Reading Project Model Variable File */
                        var PMnd = open("/".join(CSVfilesPath, "ProjectModelVariable.csv"), iomode.r);
                        var PMndChannel = PMnd.reader();
                        while PMndChannel.readln(line) {
                            var Temp: list(string);
                            for i in line.split(","){
                                Temp.append(i);
                            }
                            VariableNames = Temp[0];
                            VariablesUnits = Temp[1];
                            VariablesMeasureTables = Temp[2];
                            VariablesNumStations = Temp[3]:int;
                        }
                        PMnd.close();
                        PerformanceIndicatorFillSingle();
                        ProjectModelVariableFillSingle();
                        MeasurementLookupFillSingle();
                    } else if (CalibrationType == "Multi-Objective"){
                        
                        var PFReferenceIDs: list(string); 
                        var VariableNamesMulti: list(string);
                        var VariableWeightsMulti: list(string);
                        var IndicatorNamesMulti: list(list(string));
                        var IndicatorMaxlimitsMulti: list(list(string));
                        var IndicatorMinlimitsMulti: list(list(string));
                        var IndicatorsWeightsMulti: list(list(string));
                        var VariablesMeasureTablesMulti: list(string);
                        var VariablesNumStationsMulti: list(string);
                        var VariablesUnitsMulti: list(string);
                        var StationsMeasureIDsMulti: list(list(string));
                        var StationsSimuIDsMulti: list(list(string));
                        var LocationTypesMulti: list(list(string));
                        var IMWEBsFieldMulti: list(string);
                        var IMWEBsFieldIDMulti: list(string);
                        var StationWeightsMulti: list(list(string));
                        BaseProjectFill();
                        InsertIMWEBsProgramTable();
                        OptimizationGeneralInfoTableMultiObjectiveFunc();
                    
                        proc PerformanceIndicatorFillMultiVar(){
            
                            
                            var VariablesString = VariableNamesMulti[0];
                            var varweightString = VariableWeightsMulti[0];
                            var Indicone = IndicatorNamesMulti[0];
                            var maxone = IndicatorMaxlimitsMulti[0];
                            var minone = IndicatorMinlimitsMulti[0];
                            var weightone = IndicatorsWeightsMulti[0];

                            var IndictorNamesString = Indicone[0];
                            var IndicatorMaxlimitsString = maxone[0];
                            var IndicatorMinlimitsString = minone[0];
                            var IndicatorsWeightsString = weightone[0];
                            var n = VariableNamesMulti.size -1; 
                            var m = Indicone.size -1;
                            for i in 1..m {

                                IndictorNamesString  = ",".join(IndictorNamesString, IndicatorNamesMulti[0][i]);
                                IndicatorMaxlimitsString   = ",".join(IndicatorMaxlimitsString , IndicatorMaxlimitsMulti[0][i]);
                                IndicatorMinlimitsString = ",".join(IndicatorMinlimitsString, IndicatorMinlimitsMulti[0][i]);
                                IndicatorsWeightsString = ",".join(IndicatorsWeightsString, IndicatorsWeightsMulti[0][i]);
                                
                            }
                            for i in 1..n {
                                VariablesString  = ",".join(VariablesString, VariableNamesMulti[i]);
                                varweightString  = ",".join(varweightString, VariableWeightsMulti[i]);
                                for j in 0..IndicatorNamesMulti[0].size-1 {
                                    IndictorNamesString  = ",".join(IndictorNamesString, IndicatorNamesMulti[i][j]);
                                    IndicatorMaxlimitsString   = ",".join(IndicatorMaxlimitsString , IndicatorMaxlimitsMulti[i][j]);
                                    IndicatorMinlimitsString = ",".join(IndicatorMinlimitsString, IndicatorMinlimitsMulti[i][j]);
                                    IndicatorsWeightsString = ",".join(IndicatorsWeightsString, IndicatorsWeightsMulti[i][j]);
                                }
                                
                            }
                            var command = "dotnet run InsertIntoPerformanceIndicMultiVar";
                            var input = " ".join(command, VariablesString, varweightString, IndictorNamesString, IndicatorMaxlimitsString, IndicatorMinlimitsString, IndicatorsWeightsString, SlurmTMP, "--project", EFProjectPath);
                            var Spawncommand = spawnshell(input);
                            Spawncommand.wait();
                        }
                        proc PerformanceIndicatorFillMultiVarInd(){
                            
                            var k = VariableNamesMulti.size -1; 
                            var VariablesString = VariableNamesMulti[0];
                            var IndictorNamesString: string; 
                            var IndicatorMaxlimitsString:string;
                            var IndicatorMinlimitsString: string; 
                            var IndicatorsWeightsString: string;
                            for i in IndicatorNamesMulti[0]{
                                if (IndictorNamesString.size == 0){
                                    IndictorNamesString = i ;
                                } else {
                                    IndictorNamesString =  ":".join(IndictorNamesString, i);
                                }
                            }
                            for i in IndicatorMaxlimitsMulti[0]{
                                if (IndicatorMaxlimitsString.size == 0){
                                    IndicatorMaxlimitsString = i ;
                                } else {
                                    IndicatorMaxlimitsString =  ":".join(IndicatorMaxlimitsString, i);
                                }
                            }
                            for i in IndicatorMinlimitsMulti[0]{
                                if (IndicatorMinlimitsString.size == 0){
                                    IndicatorMinlimitsString = i ;
                                } else {
                                    IndicatorMinlimitsString = ":".join(IndicatorMinlimitsString, i);
                                }
                            }
                            for i in IndicatorsWeightsMulti[0]{
                                if (IndicatorsWeightsString.size == 0){
                                    IndicatorsWeightsString = i ;
                                } else {
                                    IndicatorsWeightsString =  ":".join(IndicatorsWeightsString, i);
                                }
                            }
                            for j in 1..k {
                                VariablesString  = ",".join(VariablesString, VariableNamesMulti[j]);
                                var tempstring = IndicatorNamesMulti[j][0];
                                for i in 1..IndicatorNamesMulti[j].size-1{
                                    tempstring =  ":".join(tempstring, IndicatorNamesMulti[j][i]);
                                }
                                IndictorNamesString =  ",".join(IndictorNamesString, tempstring);
                                var tempstring2 = IndicatorMaxlimitsMulti[j][0];
                                for i in 1..IndicatorMaxlimitsMulti[j].size-1{
                                    tempstring2 =  ":".join(tempstring2, IndicatorMaxlimitsMulti[j][i]);
                                }
                                IndicatorMaxlimitsString =  ",".join(IndicatorMaxlimitsString, tempstring2);
                                var tempstring3 = IndicatorMinlimitsMulti[j][0];
                                for i in 1..IndicatorMinlimitsMulti[j].size-1{
                                    tempstring3 = ":".join(tempstring3, IndicatorMinlimitsMulti[j][i]);
                                }
                                IndicatorMinlimitsString =  ",".join(IndicatorMinlimitsString, tempstring3);
                                var tempstring4 = IndicatorsWeightsMulti[j][0];
                                for i in 1..IndicatorsWeightsMulti[j].size-1{
                                    tempstring4 = ":".join(tempstring4, IndicatorsWeightsMulti[j][i]);
                                }
                                IndicatorsWeightsString  =  ",".join(IndicatorsWeightsString, tempstring4);
                            }
                            var command = "dotnet run InsertIntoPerformanceIndicMultiVarIndic";
                            var input = " ".join(command, VariablesString, IndictorNamesString, IndicatorMaxlimitsString, IndicatorMinlimitsString, IndicatorsWeightsString, SlurmTMP, "--project", EFProjectPath);
                            var Spawncommand = spawnshell(input);
                            Spawncommand.wait();
                        }
                        proc ProjectModelVariableFillMulti(){
                            var projectVars: list(string); 
                            var n = VariableNamesMulti.size -1; 
                            for i in 0..n {
                                if (projectVars.contains(VariableNamesMulti[i]) == false){
                                    projectVars.append(VariableNamesMulti[i]);
                                }
                            }
                            var VariablesString = projectVars[0];
                            var VariablesUnitsString = VariablesUnitsMulti[0];
                            var VariablesMeasureTablesString = VariablesMeasureTablesMulti[0];
                            var VariablesNumStationsString = VariablesNumStationsMulti[0];
                            var m = projectVars.size -1; 
                            for i in 1..m {
                                
                                VariablesString  = ",".join(VariablesString, projectVars[i]);
                                VariablesUnitsString  = ",".join(VariablesUnitsString, VariablesUnitsMulti[i]);
                                VariablesMeasureTablesString   = ",".join(VariablesMeasureTablesString , VariablesMeasureTablesMulti[i]);
                                VariablesNumStationsString = ",".join(VariablesNumStationsString, VariablesNumStationsMulti[i]);
                            }
                            var command = "dotnet run InsertIntoProjectVarMulti";
                            var input = " ".join(command, VariablesString, ProjectName, VariablesUnitsString, VariablesMeasureTablesString, VariablesNumStationsString, SlurmTMP, "--project", EFProjectPath);
                            var Spawncommand = spawnshell(input);
                            Spawncommand.wait();
                        }
                        proc MeasurementLookupFillMulti(){

                            var VariablesString = VariableNamesMulti[0];
                            var IMWEBsFieldstring = IMWEBsFieldMulti[0];
                            var IMWEBsFieldsIDtring =IMWEBsFieldIDMulti[0];
                            var MeasIDs: string;
                            var SimuIDs: string;
                            var LocationTypesString: string;
                            var StationWeightsString: string;

                            var n = StationsMeasureIDs.size -1; 
                            
                            for i in StationsMeasureIDsMulti[0]{
                                if (MeasIDs.size == 0){
                                    MeasIDs = i ;
                                } else {
                                    MeasIDs =  ":".join(MeasIDs, i);
                                }
                            }
                            for i in StationsSimuIDsMulti[0]{
                                if (SimuIDs.size == 0){
                                    SimuIDs = i ;
                                } else {
                                    SimuIDs=  ":".join(SimuIDs, i);
                                }
                            }
                            for i in LocationTypesMulti[0]{
                                if (LocationTypesString .size == 0){
                                    LocationTypesString  = i ;
                                } else {
                                    LocationTypesString  = ":".join(LocationTypesString , i);
                                }
                            }
                            for i in StationWeightsMulti[0]{
                                if (StationWeightsString.size == 0){
                                    StationWeightsString = i ;
                                } else {
                                    StationWeightsString =  ":".join(StationWeightsString, i);
                                }
                            }
                            n = VariableNamesMulti.size -1; 
                            for j in 1..n {
                                VariablesString  = ",".join(VariablesString, VariableNamesMulti[j]);
                                IMWEBsFieldsIDtring = ",".join(IMWEBsFieldsIDtring, IMWEBsFieldIDMulti[j]);
                                IMWEBsFieldstring = ",".join(IMWEBsFieldstring, IMWEBsFieldMulti[j]);
                                var MeasIDsIn: string;
                                var SimuIDsIn: string;
                                var LocationTypesStringIn: string;
                                var StationWeightsStringIn: string;
                                for i in StationsMeasureIDsMulti[j] {
                                    if (MeasIDsIn.size == 0){
                                        MeasIDsIn = i ;
                                    } else {
                                        MeasIDsIn =  ":".join(MeasIDsIn, i);
                                    }
                                }
                                MeasIDs =  ",".join(MeasIDs, MeasIDsIn);
                                for i in StationsSimuIDsMulti[j] {
                                   if (SimuIDsIn.size == 0){
                                        SimuIDsIn = i ;
                                    } else {
                                        SimuIDsIn= ":".join(SimuIDsIn, i);
                                    }
                                }
                                SimuIDs=  ",".join(SimuIDs, SimuIDsIn);
                                for i in LocationTypesMulti[j] {
                                    if (LocationTypesStringIn .size == 0){
                                        LocationTypesStringIn  = i ;
                                    } else {
                                        LocationTypesStringIn  = ":".join(LocationTypesStringIn , i);
                                    }
                                }
                                LocationTypesString=  ",".join(LocationTypesString, LocationTypesStringIn);
                                for i in StationWeightsMulti[j] {
                                    if (StationWeightsStringIn.size == 0){
                                        StationWeightsStringIn = i ;
                                    } else {
                                        StationWeightsStringIn =  ":".join(StationWeightsStringIn, i);
                                    }
                                }
                                StationWeightsString= ",".join(StationWeightsString, StationWeightsStringIn);
                            }
                            var command = "dotnet run InsertIntoMeasureLookupMulti";
                            var input = " ".join(command, VariablesString, MeasIDs, SimuIDs, LocationTypesString, StationWeightsString, IMWEBsFieldstring, IMWEBsFieldsIDtring, SlurmTMP, "--project", EFProjectPath);
                            var Spawncommand = spawnshell(input);
                            Spawncommand.wait();

                        } 
                        /*Reading Project Model Variable File */
                        var line: string; 
                        var PMnd = open("/".join(CSVfilesPath, "MultiProjectModelVariable.csv"), iomode.r);
                        var PMndChannel = PMnd.reader();
                        while PMndChannel.readln(line) {
                            var Temp: list(string);
                            for i in line.split(","){
                                Temp.append(i);
                            }
                            VariableNamesMulti.append(Temp[0]);
                            VariablesUnitsMulti.append(Temp[1]);
                            VariablesMeasureTablesMulti.append(Temp[2]);
                            VariablesNumStationsMulti.append(Temp[3]);
                        }
                        PMnd.close();
                        ProjectModelVariableFillMulti();
                        VariableNamesMulti.clear();
                        /*Reading Performance Indicators File */
                        var PInd = open("/".join(CSVfilesPath, "MultiPerformanceIndicator.csv"), iomode.r);
                        var PIndChannel = PInd.reader();
                        var Temp: list(string);
                        while PIndChannel.readln(line) {
                            for i in line.split(","){
                                Temp.append(i);
                            }
                        }
                        PInd.close();
                        var n = Temp.size/6 -1;
                        for i in 0..n {
                            if (VariableNamesMulti.contains(Temp[i*6]) == false){
                                VariableNamesMulti.append(Temp[i*6]);
                                VariableWeightsMulti.append(Temp[(i*6) + 5]);
                            }
                        }
                        for vari in VariableNamesMulti{
                            var indics: list(string);
                            var indicsMax: list(string);
                            var indicsMin: list(string);
                            var indicsWeight: list(string);
                            for i in 0..n {
                                if (Temp[i*6] == vari) {
                                    indics.append(Temp[(i*6) + 1]);
                                    indicsMax.append(Temp[(i*6) + 2]);
                                    indicsMin.append(Temp[(i*6) + 3]);
                                    indicsWeight.append(Temp[(i*6) + 4]);
                                }
                            } 
                            IndicatorNamesMulti.append(indics);
                            IndicatorMaxlimitsMulti.append(indicsMax);
                            IndicatorMinlimitsMulti.append(indicsMin);
                            IndicatorsWeightsMulti.append(indicsWeight);
                        }
                        /*Reading Measurement Lookup File */
                        var MLnd = open("/".join(CSVfilesPath, "MultiMeasurementLookup.csv"), iomode.r);
                        var MLndChannel = MLnd.reader();
                        while MLndChannel.readln(line) {
                            var Temp: list(string);
                            for i in line.split(","){
                                Temp.append(i);
                            }
                            var n = Temp.size/6 -1;
                            for i in 0..n {
                                var MeasureIDs: list(string);
                                var SimuIDs: list(string);
                                var loctype: list(string);
                                var staweight: list(string);
                                IMWEBsFieldMulti.append(Temp[(i*6) + 5]);
                                IMWEBsFieldIDMulti.append(Temp[(i*6) + 6]);
                                for j in 0..n {
                                    if (Temp[(i*6)] == Temp[(j*6)]){
                                        MeasureIDs.append(Temp[(i*6) + 1]);
                                        SimuIDs.append(Temp[(i*6) + 2]);
                                        loctype.append(Temp[(i*6) + 3]);
                                        staweight.append(Temp[(i*6) + 4]);
                                    }
                                }
                                StationsMeasureIDsMulti.append(MeasureIDs);
                                StationsSimuIDsMulti.append(SimuIDs);
                                LocationTypesMulti.append(loctype);
                                StationWeightsMulti.append(staweight);
                            }
                        } 
                        MLnd.close();
                        if (MultiObjType == "Multi-VarIndicator"){
                            PerformanceIndicatorFillMultiVarInd();
                        } 
                        if (MultiObjType == "Multi-Variable"){
                            PerformanceIndicatorFillMultiVar();
                        }
                        if (MultiObjType == "Multi-Indicator"){
                            PerformanceIndicatorFillMultiVar();
                        }
                        if (MultiObjType == "Multi-VarIndicator" || MultiObjType == "Multi-Variable"){
                            MeasurementLookupFillMulti();
                        } else {
                            MeasurementLookupFillSingle();
                        }
                
                    }
                    proc CalibrationParametersFill() {
                    
                        var CalIDString: string = ParameterIDs[0];
                        var CalNamesString: string = ParNames[0];
                        var CalAssoVar: string = ParAssoVar[0];
                        var n = ParameterIDs.size - 1; 

                        for i in 1..n{
                            CalIDString = ",".join(CalIDString, ParameterIDs[i]);
                            CalNamesString = ",".join(CalNamesString, ParNames[i]);
                            CalAssoVar = ",".join(CalAssoVar, ParAssoVar[i]);
                        }
                        var command = "dotnet run InsertIntoCalibrationParameters";
                        var input = " ".join(command, CalIDString, CalNamesString, CalAssoVar, SlurmTMP, "--project", EFProjectPath);
                        var Spawncommand = spawnshell(input);
                        Spawncommand.wait();
                    }
                    proc InsertSimulationSummaries(){

                        var Command = "dotnet run InsertIntoSimulationSummaries";
                        var SummaryString: string = SummaryTypes[0];
                        var TablesString: string;
                        for k in TableAliasLists[0]{
                            if (TablesString.size == 0){
                                TablesString = k;
                            } else {
                                TablesString = ":".join(TablesString, k);
                            }
                        }
                        var n = SummaryTypes.size - 1;
                        for i in 1..n {
                            SummaryString = ",".join(SummaryString, SummaryTypes[i]);
                            var TempTablestring: string; 
                            for j in TableAliasLists[i]{
                                if (TempTablestring.size == 0){
                                    TempTablestring = j;
                            } else {
                                TempTablestring = ":".join(TempTablestring, j);
                            }
                            TablesString = ",".join(TablesString, TempTablestring);
                            }
                        }
                        var Input = " ".join(Command, SummaryString, TablesString, ProjectName, SlurmTMP, "--project", EFProjectPath);

                        var Spcommand = spawnshell(Input);
                        Spcommand.wait();
                    }
                    /*Reading Simulation Summaries File */
                    var SSnd = open("/".join(CSVfilesPath, "SimulationSummaries.csv"), iomode.r);
                    var SSndChannel = SSnd.reader();
                    var line: string; 
                    var Temp: list(string);
                    while SSndChannel.readln(line) {
                        for i in line.split(","){
                            Temp.append(i);
                        }
                    }
                    var summaries: list(string);
                    for i in 0..Temp.size/2-1{
                        summaries.append(Temp[(2*i)+1]);
                    }
                    SSnd.close();
                    var n = summaries.size -1;
                    for i in 0..n {
                        var tablesTemp: list(string);
                        if (SummaryTypes.contains(summaries[i]) == false){
                            SummaryTypes.append(summaries[i]);
                        }
                        for j in 0..n {
                            if (summaries[i] == summaries[j]){
                                tablesTemp.append(Temp[2*j]);
                            }
                        }
                        if (TableAliasLists.contains(tablesTemp) == false){
                            TableAliasLists.append(tablesTemp);
                        }
                    } 
                    /*Reading Calibration Parameters File */
                    var CPnd = open("/".join(CSVfilesPath, "CalibrationParameters.csv"), iomode.r);
                    var CPndChannel = CPnd.reader();
                    while CPndChannel.readln(line) {
                        var Temp: list(string);
                        for i in line.split(","){
                            Temp.append(i);
                        }
                        ParameterIDs.append(Temp[0]);
                        ParNames.append(Temp[1]);
                        ParAssoVar.append(Temp[2]);
                        
                    }
                    CPnd.close();
                    CalibrationParametersFill(); 
                    InsertSimulationSummaries();

                }
            }
        }
    }
    /* If We have Pareto Front  */
        /*Reading Performance Indicators File 


            var PFnd = open(".../ParetoFront.csv", iomode.r);
            var PFndChannel = PFnd.reader();
            var line: string; 
            while PFndChannel.readln(line) {
                var Temp: list(string);
                for i in line.split(","){
                    Temp.append(i);
                }
            }
            PFnd.close();
            var n = Temp.size/5 -1;
            for i in 0..n {
                PFReferenceIDs.append(Temp[i*5]);
            }
            for i in 0..n {
                if (Temp[(i*5)] == PFReferenceIDs[0]){
                    VariableNames.append(Temp[(i*5) +1]);
                }
            }
            for i in 0..n {
                if (Temp[(i*5)] == PFReferenceIDs[0]){
                    VariableNames.append(Temp[(i*5) +1]);
                }
            }
            var m = VariableNames.size -1;
            for i in 0..n {
                var totalf: list(string);
                for j in PFReferenceIDs{
                    if (Temp[(i*5)] == j){

                        totalf.append(Temp[(i*5) + 2])
                    }
                }
                TotalF.append(totalf); 
            }
            for j in 0..m {
                var indics: list(string);
                var indicvalue: list(string);
                for for i in 0..n {
                    if (VariableNames[j] == Temp[(i*5) +1]){
                        indics.append(Temp[(i*5) + 3])
                        indicvalue.append(Temp[(i*5) + 4]);
                    }
                }
                IndicatorValues.append(indicvalue);
                IndicatorNames.append(indics);
            }
    */
}