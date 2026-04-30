global class DataCloudSyncScheduler implements Schedulable {
    global void execute(SchedulableContext sc){
       IDataSyncOperation footfallSync = new FootfallDataSyncImpl();
       footfallSync.executeSync(); 
    }	
}