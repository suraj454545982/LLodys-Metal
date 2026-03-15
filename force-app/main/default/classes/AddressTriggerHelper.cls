public class AddressTriggerHelper {

    public static void handleShippingAddressUpdate(
        List<Address__c> newList,
        Map<Id, Address__c> oldMap
    ) {
        List<Account> accountsToUpdate = new List<Account>();

        for (Address__c addr : newList) {
            Address__c oldAddr = oldMap.get(addr.Id);
            if (oldAddr == null) continue;

            Boolean shippingChanged =
                addr.Shipping_Address__Street__s != oldAddr.Shipping_Address__Street__s ||
                addr.Shipping_Address__City__s != oldAddr.Shipping_Address__City__s ||
                addr.Shipping_Address__StateCode__s != oldAddr.Shipping_Address__StateCode__s ||
                addr.Shipping_Address__PostalCode__s != oldAddr.Shipping_Address__PostalCode__s ||
                addr.Shipping_Address__CountryCode__s != oldAddr.Shipping_Address__CountryCode__s;

            if (
                shippingChanged &&
                addr.SAP_Shipping_Address_Id__c != null &&
                addr.Account__c != null
            ) {
                accountsToUpdate.add(new Account(
                    Id = addr.Account__c,
                    Is_Shipping_Update__c = true
                ));
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }
}