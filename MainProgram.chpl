use List;

proc main(args: [] string) {
   
   var temp: list(string);
   for arg in args{
       if (arg.startsWith("//")== true){
           for i in arg.split("--"){
               temp.append(i);
           }
           break;
        }
    }
    
    use IMWEBsParallelCalibrationProgram;
    var Autocalibration = new IMWEBsParallelCalibrationProgram(temp[1], temp[2], temp[3], temp[4]);
    Autocalibration.RunAutoCalibration;

    /*
    use ParallelPest;
    var ParallelPe = new ParallelPest(temp[1]);
    ParallelPe.RunParallePESTSingle;
   */
    /* Sensitivity Analysis*/
    /*
    use SA_Analysis;
    var Autocalibration = new SA_Analysis("/".join(temp[1], "PhDParallelCalProject", "EF_Database_Work"), "/".join(temp[1], "All_Libs"), "/".join(temp[1], "PhDParallelCalProject", "IMWEBs.sh"),"/".join(temp[1], "PhDParallelCalProject", "IMWEBs_SubbasinV_Linux", "build", "debug"), "/".join(temp[1], "PhDParallelCalProject", "SubareaBasedModel", "Model_cal"), "/".join(temp[1], "PhDParallelCalProject"), temp[1]);
    Autocalibration.RunSensitivityAnalysis;
    */

}
