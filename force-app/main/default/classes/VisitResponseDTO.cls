public class VisitResponseDTO {
    public List<VisitDTO> visits;        // Filtered visit records for display
    public Integer plannedCount;         // Total Planned visits for the location
    public Integer inProgressCount;      // Total In Progress visits for the location
    public Integer completedCount;       // Total Completed visits for the location
    public Integer cancelledCount;       // Total Cancelled visits for the location
}