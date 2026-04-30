public interface ISiteLocator {
    String assessNearestSite(Decimal lat, Decimal lon, String addressText);
}