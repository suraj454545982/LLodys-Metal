trigger OpportunityLineItemTrigger on OpportunityLineItem (before insert, before update,before delete) {
    
    if(Trigger.isBefore && Trigger.isInsert){
        
        // Delegate validation logic to the controller class
        OpportunityLineItemController.validateCategories(Trigger.new);
        
        //Preventing the user to add more products, when Quote Exist
        OpportunityLineItemController.blockOLICreationWhenQuoteExists(Trigger.new);
    }
    
    if(Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)){
        OpportunityLineItemController.validatePlant(
            Trigger.new,
            Trigger.isUpdate ? Trigger.oldMap : null
        );
    }
    
    if(Trigger.isBefore && Trigger.isUpdate){
        // Delegate validation logic to the controller class
        OpportunityLineItemController.validateCategories(Trigger.new);
    }
    
    if (Trigger.isBefore && Trigger.isDelete) {
        //Preventing the user to delete line item, if quote exist
        OpportunityLineItemController.blockOLIDeleteWhenQuoteExists(Trigger.old);
    }
    
    //While creating/Updating opportunity line item, if the product is blocked
    //we will show the error message in UI
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        OppQuoteLineItemMaterialBlockService.preventAddingOrUpdatingBlockedProducts(Trigger.new, Trigger.isInsert);
    }
    
    
}