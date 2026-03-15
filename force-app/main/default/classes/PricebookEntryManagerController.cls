public without sharing class PricebookEntryManagerController {
    
@AuraEnabled(cacheable=true)
public static Map<String, Object> getPricebookEntries(
    Id pricebookId,
    Integer limitSize,
    Id lastRecordId,
    String searchKey
) {
    String searchText = '%' + (searchKey == null ? '' : searchKey) + '%';

    List<PricebookEntry> entries;

    if (lastRecordId == null) {
        entries = [
            SELECT Id, UnitPrice, IsActive,
                   Product2.Name, Product2.ProductCode
            FROM PricebookEntry
            WHERE Pricebook2Id = :pricebookId
            AND Product2.Name LIKE :searchText
            ORDER BY Id
            LIMIT :limitSize
        ];
    } else {
        entries = [
            SELECT Id, UnitPrice, IsActive, Product2.Name, Product2.ProductCode   FROM PricebookEntry  WHERE Pricebook2Id = :pricebookId    AND Product2.Name LIKE :searchText   AND Id > :lastRecordId     ORDER BY Id  LIMIT :limitSize ];
    }
           
    Integer totalCount = [
        SELECT COUNT()
        FROM PricebookEntry
        WHERE Pricebook2Id = :pricebookId
        AND Product2.Name LIKE :searchText
    ];

    return new Map<String, Object>{
        'entries' => entries,
        'totalCount' => totalCount
    };
}



@AuraEnabled(cacheable=true)
public static List<Product2> getAllProducts(
    Id pricebookId,
    String searchKey,
    Integer limitSize,
    Id lastProductId
) {
    Set<Id> existingProductIds = new Set<Id>();
    for (PricebookEntry pbe : [
        SELECT Product2Id
        FROM PricebookEntry
        WHERE Pricebook2Id = :pricebookId
    ]) {
        existingProductIds.add(pbe.Product2Id);
    }

    String searchText = '%' + (searchKey == null ? '' : searchKey) + '%';

    if (lastProductId == null) {
        return [
            SELECT Id, Name, ProductCode, Description, IsActive,
                   Family, Unit_price__c, Plant__c
            FROM Product2
            WHERE IsActive = true
            AND Id NOT IN :existingProductIds
            AND Name LIKE :searchText
            ORDER BY Id
            LIMIT :limitSize
        ];
    }

    return [
        SELECT Id, Name, ProductCode, Description, IsActive,
               Family, Unit_price__c, Plant__c
        FROM Product2
        WHERE IsActive = true
        AND Id NOT IN :existingProductIds
        AND Name LIKE :searchText
        AND Id > :lastProductId
        ORDER BY Id
        LIMIT :limitSize
    ];
}





@AuraEnabled
public static void addSelectedProducts(
    Id pricebookId,
    List<Map<String, Object>> products
) {
    if (products == null || products.isEmpty()) {
        throw new AuraHandledException('Products list is empty');
    }
    system.debug('hii');

    Set<Id> productIds = new Set<Id>();
    for (Map<String, Object> p : products) {
        productIds.add((Id) p.get('Id'));
    }

    Set<Id> existingProductIds = new Set<Id>();
    for (PricebookEntry pbe : [
        SELECT Product2Id
        FROM PricebookEntry
        WHERE Pricebook2Id = :pricebookId
        AND Product2Id IN :productIds
    ]) {
        existingProductIds.add(pbe.Product2Id);
    }

    List<PricebookEntry> entriesToInsert = new List<PricebookEntry>();
system.debug('hii1'+entriesToInsert);
    for (Map<String, Object> p : products) {
        Id productId = (Id) p.get('Id');

        if (!existingProductIds.contains(productId)) {

            Decimal freight = p.get('Freight__c') != null
    ? Decimal.valueOf(String.valueOf(p.get('Freight__c')))
    : 0;

Decimal productPrice = p.get('Product_Price__c') != null
    ? Decimal.valueOf(String.valueOf(p.get('Product_Price__c')))
    : 0;



Decimal unitPrice = freight + productPrice;

 // ---- FETCH ADDITIONAL FIELDS  ----

        Decimal royalty = p.get('Royalty__c') != null? Decimal.valueOf(String.valueOf(p.get('Royalty__c'))): 0;

        Decimal portCharges = p.get('Port_and_Other_Handling_Charges__c') != null
            ? Decimal.valueOf(String.valueOf(p.get('Port_and_Other_Handling_Charges__c')))
            : 0;

        Decimal miscExpenses = p.get('Other_Miscellaneous_Expenses__c') != null
            ? Decimal.valueOf(String.valueOf(p.get('Other_Miscellaneous_Expenses__c')))
            : 0;

        Decimal taxes = p.get('DMT_and_other_taxes__c') != null
            ? Decimal.valueOf(String.valueOf(p.get('DMT_and_other_taxes__c')))
            : 0;

system.debug('hii123'+entriesToInsert);
            entriesToInsert.add(new PricebookEntry(
                Pricebook2Id = pricebookId,
                Product2Id = productId,
                Freight__c = freight,
                Product_Price__c = productPrice,
                UnitPrice = unitPrice,
                IsActive = true,
                Royalty__c = royalty,
                Port_and_Other_Handling_Charges__c = portCharges,
                Other_Miscellaneous_Expenses__c = miscExpenses,
                DMT_and_other_taxes__c = taxes,
                UseStandardPrice = false
            ));
        }
          
    }

  
    if (!entriesToInsert.isEmpty()) {
        system.debug('entriesToinsert-->'+entriesToInsert.size());
        insert entriesToInsert;
    }
}

}