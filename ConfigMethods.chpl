use ParameterSet;
use FileSystem;
use Spawn;


class Config{
    
    var ProjectPath:string;
    var hostname: string;
    var hostID:int;
    proc init(EFProjectPath:string){

        this.ProjectPath = EFProjectPath;
        this.hostname = here.hostname;  
        this.hostID = here.id;
    }
    proc addMeasurementContext(){

        var success =false;
        var command = "dotnet run GetMeasurementDB";
        var input = " ".join(command, hostname, "--project", ProjectPath);
        var MeasCommand = spawnshell(input, stdout=PIPE);
        var line:string;
        var measdbPath: string;
        while MeasCommand.stdout.readline(line) {
            measdbPath = line;
        }
        measdbPath = "/home/yang_host/Documents/SingleObjectiveDDS/MeasurementDBSingle.db";
        MeasCommand.wait();
        if FileSystem.isFile(measdbPath) {
            var arg1 = "dotnet ef dbcontext scaffold";
            var arg2 = "'Data source =";
            var arg3 = "Microsoft.EntityFrameworkCore.Sqlite";
            var arg4 = "--context-dir";
            var arg5 = "--context MeasurementDBContext --force";
            var FinalCommand = " ".join(arg1, arg2, measdbPath, "'", arg3, arg4, ProjectPath, arg5);
            var scaffold = spawnshell(FinalCommand, stdout=PIPE);
            var line:string; 
            writeln(FinalCommand);
            while scaffold.stdout.readline(line) {
                if (line.find("Build succeeded.") != -1){
                    success = true;
                    break;
                } 
            }
            scaffold.wait();
        }
        if (success == false){
            writeln("Errors in Scaffold command for Measurement Database on Locale %s", here.hostname);
        }
        return success;
    }
    proc setIntelVars(){
        var command = " bash /home/yang_host/Documents/SingleObjectiveDDS/oneapi.sh";
        var Intel = spawnshell(command, stdout=PIPE);
        var line:string; 
        while Intel.stdout.readline(line) {
            writeln(line);
        }
        Intel.wait();
    }

    proc SendISland(){
        
    }
}
