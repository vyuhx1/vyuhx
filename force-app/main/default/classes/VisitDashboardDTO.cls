public class VisitDashboardDTO {
    @AuraEnabled public String visitId;
    @AuraEnabled public String siteName;
    @AuraEnabled public String retailStore;
    @AuraEnabled public String groupName;
    @AuraEnabled public String visitorName;
    @AuraEnabled public String status;
    @AuraEnabled public String priority;
    @AuraEnabled public String plannedStart;
    @AuraEnabled public String plannedEnd;
    @AuraEnabled public String actualStart;
    @AuraEnabled public String actualEnd;
    @AuraEnabled public Decimal latitude;
    @AuraEnabled public Decimal longitude;
}