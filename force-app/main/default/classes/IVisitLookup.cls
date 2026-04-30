public interface IVisitLookup {
    /**
     * @param siteName            Filter by Sites__c name (Context.Name LIKE)
     * @param retailStoreName     Filter by RetailStore name
     * @param retailStoreGroupName Filter by RetailLocationGroup name
     * @param statusFilter        'Planned', 'InProgress', 'Completed', 'Cancelled' — null = all
     * @param dateFilter          'Today', 'Yesterday', or 'dd-MM-yyyy' — applied to ActualVisitEndTime
     */
    List<VisitDTO> lookupVisits(String siteName, String retailStoreName,
                                String retailStoreGroupName, String statusFilter,
                                String dateFilter);

    /**
     * Returns count of visits per Status for the same location + date filters.
     * statusFilter is intentionally excluded so all statuses are always counted.
     */
    Map<String, Integer> countVisits(String siteName, String retailStoreName,
                                     String retailStoreGroupName, String dateFilter);
}