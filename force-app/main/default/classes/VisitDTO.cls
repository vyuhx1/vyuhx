public class VisitDTO {
    public String visitId;
    public String siteId;          // ContextId (Sites__c) — for record navigation
    public String siteName;        // Context.Name (Sites__c name)
    public String retailStore;     // Context.Retail_Store__r.Name
    public String groupName;       // Context.Retail_Store__r.RetailLocationGroup.Name
    public String visitorName;     // Visitor.Name
    public String status;          // API value: Planned, InProgress, Completed, Cancelled
    public String priority;        // VisitPriority picklist value
    public String plannedStart;    // Formatted PlannedVisitStartTime
    public String plannedEnd;      // Formatted PlannedVisitEndTime
    public String actualStart;     // Formatted ActualVisitStartTime
    public String actualEnd;       // Formatted ActualVisitEndTime
    public String statusRemarks;   // StatusRemarks
    public String instructions;    // InstructionDescription
    public Decimal latitude;       // Site latitude for client-side Maps URL
    public Decimal longitude;      // Site longitude for client-side Maps URL
    public List<VisitNoteDTO> notes; // Up to 3 most recent ContentNotes
}