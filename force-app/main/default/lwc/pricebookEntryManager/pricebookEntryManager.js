import { LightningElement, api, track } from 'lwc';
import getPricebookEntries from '@salesforce/apex/PricebookEntryManagerController.getPricebookEntries';
import getAllProducts from '@salesforce/apex/PricebookEntryManagerController.getAllProducts';
import addSelectedProducts from '@salesforce/apex/PricebookEntryManagerController.addSelectedProducts';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PricebookEntryManager extends LightningElement {
 @api recordId;
limitSize = 50;
isLoading = false;
allDataLoaded = false;
searchEntryKey = '';

@track pricebookEntries = [];
@track totalRecords = 0;


lastRecordId = null;
lastProductId = null;
productLimit = 50;
productAllLoaded = false;
isProductLoading = false;



    @track pricebookEntries = [];
    @track products = [];
    @track selectedProducts = [];
    @track editableProducts = [];
    @track searchKey = '';
    @track isProductSelectModal = false;
    @track isProductEditModal = false;
    @track selectedProductIds = [];
    @track draftValues = [];
@track entryCount = 0;



get selectedProductsCount() {
    return this.selectedProducts.length;
}


columns = [
   {
      label: 'Product Name',
      fieldName: 'pbeUrl',
      type: 'url',
      typeAttributes: {
          label: { fieldName: 'ProductName' }, // This shows the name
          target: '_self'
      }
   },
   { label: 'Product Code', fieldName: 'ProductCode', type: 'text' },
   { label: 'List Price', fieldName: 'UnitPrice', type: 'currency', cellAttributes: { alignment: 'left' } },
   { label: 'Active', fieldName: 'IsActive', type: 'boolean' }
];




    productColumns = [
        { label: 'Product Name', fieldName: 'Name', type: 'text' },
        { label: 'Product Code', fieldName: 'ProductCode', type: 'text' },
        { label: 'Description', fieldName: 'Description', type: 'text' },
        { label: 'Family', fieldName: 'Family', type: 'text' },
        { label: 'List Price', fieldName: 'Unit_price__c', type: 'currency' ,cellAttributes: { alignment: 'left' }},
        { label: 'Plant', fieldName: 'Plant__c', type: 'Number' },
        { label: 'Active', fieldName: 'IsActive', type: 'boolean' }

    ];

 editColumns = [
 { label:'Product', fieldName:'Name', type:'text', editable:false },
 { label:'List Price', fieldName:'Product_Price__c', type:'number', editable:true, typeAttributes:{ maximumFractionDigits:3 }},
 { label:'Freight', fieldName:'Freight__c', type:'number', editable:true, typeAttributes:{ maximumFractionDigits:3 }},
 { label:'Royalty', fieldName:'Royalty__c', type:'number', editable:true, typeAttributes:{ maximumFractionDigits:3 }},
 { label:'Port Charges', fieldName:'Port_and_Other_Handling_Charges__c', type:'number', editable:true, typeAttributes:{ maximumFractionDigits:3 }},
 { label:'Misc Expenses', fieldName:'Other_Miscellaneous_Expenses__c', type:'number', editable:true, typeAttributes:{ maximumFractionDigits:3 }},
 { label:'Taxes', fieldName:'DMT_and_other_taxes__c', type:'number', editable:true, typeAttributes:{ maximumFractionDigits:3 }},
 { label:'Product Code', fieldName:'ProductCode', type:'text', editable:false }
];




    connectedCallback() {
        this.loadEntries();
        console.log('pricebookId in connectedCallback-->'+this.recordId);
    
    }

loadEntries(reset = false) {
    if (this.isLoading) return;

    if (reset) {
        this.pricebookEntries = [];
        this.lastRecordId = null;
        this.allDataLoaded = false;
    }

    this.isLoading = true;

    getPricebookEntries({
        pricebookId: this.recordId,
        limitSize: this.limitSize,
        lastRecordId: this.lastRecordId,
        searchKey: this.searchEntryKey
    })
    .then(result => {
        const entries = result.entries || [];
        this.totalRecords = result.totalCount || 0;

        if (entries.length < this.limitSize) {
            this.allDataLoaded = true;
        }

        const newRows = entries.map(e => ({
            Id: e.Id,
            ProductName: e.Product2?.Name,
            ProductCode: e.Product2?.ProductCode,
            UnitPrice: e.UnitPrice,
            IsActive: e.IsActive,
            pbeUrl: '/' + e.Id
        }));

        this.pricebookEntries = [...this.pricebookEntries, ...newRows];

        if (entries.length > 0) {
            this.lastRecordId = entries[entries.length - 1].Id;
        }
    })
    .finally(() => {
        this.isLoading = false;
    });
}



handleProductScroll(event) {
    const { scrollTop, scrollHeight, clientHeight } = event.target;

    if (scrollTop + clientHeight >= scrollHeight - 10) {
        this.loadProducts();
    }
}






get hasMoreRecords() {
    return !this.allDataLoaded;
}
handleLoadMore() {
    if (!this.allDataLoaded) {
        this.loadEntries();
    }
}
handleEntrySearch(event) {
    this.searchEntryKey = event.target.value;
    this.loadEntries(true);
}








    handleOpenModal() {
        this.isProductSelectModal = true;
        this.loadProducts();
    }

    handleCloseModal() {
        this.isProductSelectModal = false;
        this.isProductEditModal = false;
       // window.location.reload();
    }

handleSearch(event) {
    this.searchKey = event.target.value;
    this.loadProducts(true);
}



loadProducts(reset = false) {
    if (this.isProductLoading) return;

    if (reset) {
        this.products = [];
        this.lastProductId = null;
        this.productAllLoaded = false;   // 🔥 MUST reset
    }

    this.isProductLoading = true;

    getAllProducts({
        pricebookId: this.recordId,
        searchKey: this.searchKey,
        limitSize: this.productLimit,
        lastProductId: this.lastProductId
    })
    .then(result => {
 console.log('Fetched products from Apex:', JSON.stringify(result));
        console.log('Previous lastProductId:', this.lastProductId);
        if (result.length < this.productLimit) {
            this.productAllLoaded = true;
             console.log('All products loaded, setting productAllLoaded = true');
        }

        const map = new Map();
        [...this.products, ...result].forEach(p => map.set(p.Id, p));
        this.products = [...map.values()];

        if (result.length > 0) {
            this.lastProductId = result[result.length - 1].Id;
              console.log('Updated lastProductId:', this.lastProductId);
        }

        this.selectedProductIds = this.products
            .filter(p => this.selectedProducts.some(sp => sp.Id === p.Id))
            .map(p => p.Id);
              console.log('Total products now in table:', this.products.length);
    })
    .finally(() => {
        this.isProductLoading = false;
          console.log('isProductLoading set to false');
    });
}






handleProductSelect(event) {
    const newlySelected = event.detail.selectedRows;

    // Add newly selected rows to master selection
    newlySelected.forEach(row => {
        if (!this.selectedProducts.some(p => p.Id === row.Id)) {
            this.selectedProducts.push(row);
        }
    });

    // Remove rows that were deselected
    this.selectedProducts = this.selectedProducts.filter(
        p => this.products.some(prod => prod.Id === p.Id && newlySelected.some(n => n.Id === p.Id)) 
          || !this.products.some(prod => prod.Id === p.Id) // keep previously selected not in current products
    );

    // Update selectedProductIds to reflect currently checked rows in current table
    this.selectedProductIds = newlySelected.map(p => p.Id);
}




    handleAddProducts() {
        if (this.selectedProducts.length === 0) {
            this.showToast('Warning', 'Please select at least one product.', 'warning');
            return;
        }
        this.isProductSelectModal = false;
        this.isProductEditModal = true;
       console.log('selectedProductin AddProduct--->'+JSON.stringify(this.editableProducts));
    this.editableProducts = this.selectedProducts.map(prod => ({
    Id: prod.Id,
    Name: prod.Name,
    ProductCode: prod.ProductCode,
    Freight__c: 0,
    Product_Price__c: prod.Unit_price__c || 0,
    Rolayty__c: 0,
    Port_and_Other_Handling_Charges__c: 0,
    Other_Miscellaneous_Expenses__c: 0,
    DMT_and_other_taxes__c: 0
}));


    }

handleCellChange(event) {
    const changes = event.detail.draftValues;

    changes.forEach(change => {
        const index = this.editableProducts.findIndex(p => p.Id === change.Id);
        if (index !== -1) {
            this.editableProducts[index] = {
                ...this.editableProducts[index],
                ...change
            };
        }
    });
}

handleProductLoadMore(event) {
    if (this.productAllLoaded || this.isProductLoading) {
        event.target.isLoading = false;
        return;
    }

    this.loadProducts();
}



handleFinalSave() {
    console.log('Saving products -->', JSON.stringify(this.editableProducts));

    addSelectedProducts({
        pricebookId: this.recordId,
        products: this.editableProducts
    })
    .then(() => {
        this.showToast('Success', 'Pricebook Entries created successfully.', 'success');
        this.isProductEditModal = false;
        this.editableProducts = [];
        this.selectedProducts = [];
        this.loadEntries();
    })
    .catch(error => {
        console.error(error);
        this.showToast(
            'Error',
            error.body?.message || 'Error saving records',
            'error'
        );
    });
    window.location.reload();
}






    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}