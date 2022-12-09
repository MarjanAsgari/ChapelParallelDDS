use ParameterSet;
use DateTime; 
use FileSystem;
use IO;
use List;
use Spawn;
use ProgramDatabase ;
use ConfigMethods;
/*
Constants I used -->
  1- Global -->  For Parameter Type 
*/

class IMWEBs{

    /* The point here is that I MUST define the memory management strategy to let the compiler create a list with the type of the given class.
        The strategy here is shared */

   
    var StartDateTime: string; /* In order to be able to check the execution time of a simulation, we have this variable and will fill it right before IMWEBs execution  */
    var EndDateTime: string; /* In order to be able to check the execution time of a simulation, we have this variable and will fill it right after IMWEBs execution  */
    var EFProject: string; /* This is the directory of the EF project we have */
    var SimulationRunTime: real; /* This variable is the subtraction of start time from the end time for each single IMWEBS simulation run */
    var hostname: string; /* This is for storing the name of the Remote Computer */ 
    var IMWEBsprogram: string; /* From the IMWEBsProgram Table, we read the name of program which should be executed for each IMWEBs simulation and store the name in this variable */ 
    var ProjectName: string; /* In our Base_Project table we might have multiple project names, we need to make sure that the program will be run for the right project. So, we need to store the project name in this variable*/
    var SLRMPath:string;
    var ModelDir:string; /* This is the imwebsmain directory */
    var ApplicationDir: string; /* This is the Project directory (where dbs and input datasets are stored) */
    var ScenarioID: string; /* This is the id that we need to pass to the IMWEBs model to run it */
    var CalibrationParSet: list(shared Parameter, parSafe=true);
    var CalTextFile: bool;
    var ProjectEndDate: date; /* In order to be able to check the progress of IMWEBs simulation, we have this variable and will fill it with the last timedate of data we have for the current project
                                In fact the progress will be calculated by comparing the dates for which the IMWEBS did simulate variables values with the entire datetime frame we have for our project  */
    var ProjectStartDate: date; /* In order to be able to check the progress of IMWEBs simulation, we have this variable and will fill it with the first timedate of data we have for the current project */
    proc init(Paras: list(shared Parameter, parSafe=true), BaseProjectName:string, EFProjectPath:string, slrumpath:string){

        this.EFProject = EFProjectPath;
        this.hostname = here.hostname;
        this.ProjectName = BaseProjectName;
        this.SLRMPath = slrumpath;
        
        /* By Running the command below, we query the right tables to get ScenarioID, IMWEBs Model Path and Application PAth which is the project path  */
        var Paths_Command = " ".join("dotnet run getPaths", ProjectName, hostname, SLRMPath, "--project", EFProject);
        var PathsCom = spawnshell(Paths_Command, stdout=PIPE);
        var line:string;
        var modeldir: string;
        var appdir: string;
        var scen: string;
        while PathsCom.stdout.readline(line) {
            var Paths_List: list(string);
            for i in line.split(","){
                for j in i.split(":"){
                    Paths_List.append(j);
                }
            }
            for i in 0..#((Paths_List.size / 2) - 1){
                if (Paths_List[i*2] == "IMWEBspath"){
                    modeldir = Paths_List[(i*2)+1];
                }
                if (Paths_List[i*2] == "ApplicationPath"){
                    appdir = Paths_List[(i*2)+1];
                }
                if (Paths_List[i*2] == "ScenID"){
                    scen = Paths_List[(i*2)+1];
                }
            }
        }
        PathsCom.wait();
        this.ModelDir = modeldir;
        this.ApplicationDir = appdir;
        this.ScenarioID = scen;
        var CalPars: list(shared Parameter, parSafe=true);
        assert(CalPars.type == Paras.type);
        CalPars = Paras;
        this.CalibrationParSet = CalPars;
        /* Before running the IMWEBs model, we need to set the INTEL oneAPI (compiler) variables */
        var configuration = new Config(EFProject);
        //configuration.setIntelVars();
        /* When we get the Application directory, we get the start date and time and end date and time for the project we are using */ 
    } 

    /* Before being able to run the IMWEBs model, we need to generate a Calibration text file for the model. This Text file should be generated (updated) before running a new simulation */ 
    /* Checked in Chapel */
    proc generateCalibrationTXT(){

        /* This Text file should contain only Global parameters. So, we need to be cautious and exclude BMP Parameters from the parameter set before passing it to generate the Calibration Text file */  
        var GlobalPars: list(shared Parameter, parSafe=true) =  CalibrationParSet;
        for par in CalibrationParSet{
            if (par.getParameterType() != "General"){
                GlobalPars.remove(par);
            }
        }
        /* Here we are using IO functions to 1- delete the calibration text file if it already exists, 2- to generate  the calibration file with  updated Parameters values in the Application Directory */
        var full_path: string = "/".join(ApplicationDir,"calibration.txt");
        var FileIsCreated = false;
        var myFile = open(full_path, iomode.cw);
        var WritingChannel = myFile.writer();
        var AddedPars = 0;
        for i in GlobalPars {
            var partext = i.getCalibrationText();
            WritingChannel.writeln(partext);
            AddedPars = AddedPars + 1;
        } 
        WritingChannel.close();
        if (AddedPars == GlobalPars.size){
            FileIsCreated = true;
        }
        setCalTextFile(FileIsCreated); // We return true if the file has been created successfully
    }

    /* getLastDateLog() Function returns the last date recorded on the log file that the IMWEBs has been run for. It returns a date object.
        Point-1: if line is empty in a log file, its size will be considered 1 in Chapel. */
    proc getLastDateLog(){

        /* We need to go to the log file after the IMWEBs simulation to see for how many dates the model did simulate the variables--> This number helps us to track the simulation progress
        and if the progress is acceptable we define the IMWEBs simulation had been successful. */
        var scen_file: string = "_".join("scenario", "2");
        var logPath: string = "/".join(ApplicationDir, "output", scen_file,"log.log");
        var LogEndDate: date;
        if FileSystem.isFile(logPath) {
            try{
                var logFile = open(logPath, iomode.r);
                var ReadingChannel = logFile.reader();
                var line:string;;
                var ListDateElements: list(string);
                while(ReadingChannel.readline(line)) {
                    if (line.find("-") == -1){
                        break;
                    } else {
                        for i in line.split("-"){
                            ListDateElements.append(i);
                        }
                    }
                }
                ReadingChannel.close();
                // Here we are giving values to year, month and day from the date object. These values should be int, so I cast the string to int. 
                var size = ListDateElements.size;
                LogEndDate.init(ListDateElements[size-3]:int, ListDateElements[size-2]:int, ListDateElements[size-1]:int);
                logFile.close();
            } catch {
                writeln("Errors in opening Log.log File on Locale %s", here.hostname); // We print this message if the opening log file encounters an error 
            }
        } else {
            writeln("There is NO Log.log File on Locale %s", here.hostname); // If there is no log.log file on the Locale, we print this message. 
        }
        return LogEndDate;
    }
    /* This function is for getting the name of the program we want to run (for IMWEBS) from the appropriate table we have in our database */ 
    proc getIMWEBsProgramName(){

        var IMWEBs_Insert_command = "dotnet run IMWEBsProgram";
        var IMWEBs_Insert_input = " ".join(IMWEBs_Insert_command, hostname, SLRMPath, "--project", EFProject);
        var IMWEBs = spawnshell(IMWEBs_Insert_input, stdout=PIPE);
        var line: string;
        while IMWEBs.stdout.readline(line) {
            this.IMWEBsprogram = line;
        }
        IMWEBs.wait();
    }
    /* getProjectStartDate() Function returns the start date date recorded on file.in file. It returns a date object.
        Point 1: If a line contains a piece of specific string, it does not return -1 */
    proc ProjectStartDateCal(){
        
        /* For reading the project start date, we need to look into the file.in file on the Application directory  */
        var FileINPath: string = "/".join(ApplicationDir,"file.in");
        if FileSystem.isFile(FileINPath){
            try {
                var filein = open(FileINPath, iomode.r);
                var ReadingChannel = filein.reader();
                var line:string;
                var ListDateElements: list(string);
                var KeyString = "STARTTIME"; 
                while(ReadingChannel.readline(line)) {
                    if (line.find(KeyString) != -1){
                        var ELine = line.replace("|", "/");
                        for i in ELine.split("/"){
                            ListDateElements.append(i);
                        }
                        break;
                    }
                }
                ProjectStartDate.init(ListDateElements[1]:int, ListDateElements[2]:int, ListDateElements[3]:int);
                filein.close();
            } catch {
                writeln("Errors in opening file.in File on Locale %s", here.hostname);
            }
        } else {
            writeln("There is NO file.in File on Locale %s", here.hostname);
        }
        setProjectStartDate(ProjectStartDate);
    }
    /* getProjectStartDate() Function returns the end date date recorded on file.in file. It returns a date object.*/
    proc ProjectEndDateCal(){
        var FileINPath: string = "/".join(ApplicationDir,"file.in");
        var ProjectEndDate: date;
        if (FileSystem.isFile(FileINPath) == true){
            try {
                var filein = open(FileINPath, iomode.r);
                var ReadingChannel = filein.reader();
                var line:string;
                var ListDateElements: list(string);
                var KeyString = "ENDTIME"; 
                while(ReadingChannel.readline(line)) {
                    if (line.find(KeyString) != -1){
                        var ELine = line.replace("|", "/");
                        for i in ELine.split("/"){
                            ListDateElements.append(i);
                        }
                        break;
                    }
                }
                ProjectEndDate.init(ListDateElements[1]:int, ListDateElements[2]:int, ListDateElements[3]:int);
                filein.close();
            } catch {
                writeln("Errors in opening file.in File on Locale %s", here.hostname);
            }
        } else {
            writeln("There is NO file.in File on Locale %s", here.hostname);
        }
        setProjectEndDate(ProjectEndDate);
    }
    /* This function returns the progress (success) of the simulation for the IMWEBs model*/
    proc getProgress(){

        /* Here we calculate the amount of progress IMWEBS simulation was able to achieve.
            Chapel does not have a function to get the number of milliseconds since January 1, 1970, 00:00:00 GTM 
            Thus, I followed the method below 
        */
        ProjectEndDateCal();
        ProjectStartDateCal();
        this.ProjectEndDate = getProjectEndDate();
        this.ProjectStartDate = getProjectStartDate();
        var LogEndDate: date = getLastDateLog();
        var numerator = (365 * (LogEndDate.year - getProjectStartDate().year) + 30 * (LogEndDate.month - getProjectStartDate().month) + (LogEndDate.day - getProjectStartDate().day));
        var denominator = (365 * (ProjectEndDate.year- getProjectStartDate().year) + 30 * (ProjectEndDate.month - getProjectStartDate().month) + (ProjectEndDate.day- getProjectStartDate().day));
        var progress = (numerator/denominator) * 100;
        return progress;
    }
    /* This method 1- Runs one simulation, 2- get the success flag for the simulation execution based on the progress the model had */ 
    proc RunModel(hdf5path:string, IMWEBsbash:string){

        var successFlag = false;
        var isFile = generateCalibrationTXT(CalibrationParSet);
        if (isFile == true){
            try {
                /* Running the model starts off with deleting log file and generating calibration text file */
                getIMWEBsProgramName();
                var scen_file: string = "_".join("scenario", ScenarioID);
                var logPath: string = "/".join(ApplicationDir, "output", scen_file,"log.log");
                if (FileSystem.isFile(logPath) == true) {
                    FileSystem.remove(logPath);
                }
                var FirstLine = "#!/bin/bash";
                var ThirdLine = "".join("export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:",hdf5path); // The path we have stored the HDF5 libs
                var ImwebsCommand = "/".join(ModelDir, IMWEBsprogram);
                var ForthLine = " ".join("&& <<-EOF", ImwebsCommand, ModelDir, ApplicationDir, 2:string);
                var Fullline = " ".join(ThirdLine , ForthLine);
                var FifthLine = "EOF";
                /*var MyfilePF = IMWEBsbash;
                var myFile = open(MyfilePF, iomode.cw);
                var WritingChannel = myFile.writer();
                WritingChannel.writeln(FirstLine);
                WritingChannel.writeln(Fullline);
                WritingChannel.write(FifthLine);
                WritingChannel.close();
                */
                var FinalCommand = " ".join("bash", IMWEBsbash);
                var Imwebs = spawnshell(FinalCommand, stdout=PIPE);
                var Pline:string;
                var startDate: date = date.today();
                var datetimeS: datetime = datetime.today();
                var startTime = datetimeS.gettime();
                StartDateTime = "//".join(startDate:string, startTime:string);
                setStartTimeDate(StartDateTime);
                while Imwebs.stdout.readline(Pline) {
                    writeln(Pline);
                } 
                Imwebs.wait();
                var EndDate: date = date.today();
                var run = false;
                var datetimeE: datetime = datetime.today();
                var EndTime = datetimeE.gettime();
                setSimulationRunTime(((EndTime.hour - startTime.hour) * 60 + (EndTime.minute - startTime.minute)));
                EndDateTime = "//".join(EndDate:string, EndTime:string);
                setEndTimeDate(EndDateTime);
                var progress = getProgress();
                var running = "No";
                if (run == false && progress > 90){
                    successFlag = true;
                }
                if (run == false && progress < 90){
                    successFlag = false;
                }
                if (run == true){
                    running = "Yes";
                }
                if (successFlag == false){
                    writef("IMWEBS run failed on %s! Result = %s , Progress = %s /n" ,here.hostname, running, progress:string);
                } 
                return successFlag;
            } catch {
                writeln("Errors in Running IMWEBs Model on Locale %s", here.hostname);

            }
        }
        return successFlag;
    }
    /* Following Functions use scaffold command to add a dbcontext of all tables in Simulation and Measurement Database to the directory of  our EF Core program */
    proc addSimulationContext(){

        var success = false;
        var scen_file = "_".join("scenario", ScenarioID);
        var dbPath = "/".join(ApplicationDir, "output", scen_file,"scenario_2.db");
        if FileSystem.isFile(dbPath) {
            var arg1 = "dotnet ef dbcontext scaffold";
            var arg2 = "'Data source =";
            var arg3 = "Microsoft.EntityFrameworkCore.Sqlite";
            var arg4 = "--context-dir";
            var arg5 = "--context SimulationDB --force";
            var FinalCommand = " ".join(arg1, arg2, dbPath, "'", arg3, arg4, EFProject, arg5);
            var scaffold = spawnshell(FinalCommand, stdout=PIPE);
            var line:string; 
            while scaffold.stdout.readline(line) {
                if (line.find("Build succeeded.") != -1){
                    success = true;
                    break;
                }
            }
            scaffold.wait();
        }
        if (success == false){
            writeln("Errors in Scaffold command for Simulation Database on Locale %s", hostname);
        }
        return success;
    }
    proc DeleteLogFile(){
        var logPath: string = "/".join(ApplicationDir, "output", "scenario_2","log.log");
        if (FileSystem.isFile(logPath) == true) {
            FileSystem.remove(logPath);
        }
    }
    /* Following methods are getters and setters for the class global variable */ 
    proc getStartTimeDate(){
        return StartDateTime;
    }
    proc setStartTimeDate(value:string){
        this.StartDateTime = value;
    }
    proc getCalTextFile(){
        return CalTextFile;
    }
    proc setCalTextFile(value:bool){
        this.CalTextFile = value;
    }
    proc setEndTimeDate(value:string){
        this.EndDateTime = value;
    }
    proc getEndTimeDate(){
        return EndDateTime;
    }
    proc setSimulationRunTime(value:real){
        this.SimulationRunTime = value;
    }
    proc getSimulationRunTime(){
        return SimulationRunTime;
    }
    proc setProjectStartDate(value:date){
        this.ProjectStartDate = value;
    }
    proc getProjectStartDate(){
        return ProjectStartDate;
    }
    proc setProjectEndDate(value:date){
        this.ProjectEndDate= value;
    }
    proc getProjectEndDate(){
        return ProjectEndDate;
    }
}

