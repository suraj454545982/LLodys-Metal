import { LightningElement, track, wire } from 'lwc';
import getSurveyByUniqueId from '@salesforce/apex/SurveyController.getSurveyByUniqueId';
import updateSurvey from '@salesforce/apex/SurveyController.updateSurvey';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import SURVEY_OBJECT from '@salesforce/schema/Survey__c';
import PRIMARY_PRODUCT_FIELD from '@salesforce/schema/Survey__c.Primary_Product__c';
import ROLE_FIELD from '@salesforce/schema/Survey__c.Role__c';
import COMPANY_TYPE_FIELD from '@salesforce/schema/Survey__c.Company_Type__c';
import CLIENT_DURATION_FIELD from '@salesforce/schema/Survey__c.ClientDurationOptions__c';
import welcomeImage from '@salesforce/resourceUrl/WelcomePgae';
import ThankyouPage from '@salesforce/resourceUrl/ThankyouPage';
export default class SalesFeedbackSurvey extends LightningElement {
    @track showWelcome = false;
    @track showSurvey = false;
    @track showThankYou = false;
    @track surveyAlreadySubmitted = false;
    @track surveyId;

    @track respondentInfo = {
        name: '',
        email: '',
        phone: '',
        companyName: '',
        role: '',
        companyType: '',
        products: '',
        clientDuration: '',
        roleOther: '',
        cTOther: '',
        otp: ''
    };

    @track respondentInfoDisabled = {
        name: false,
        email: false,
        phone: false,
        companyName: false,
        role: false,
        companyType: false,
        products: false,
        clientDuration: false
    };

    @track surveyResponses = {
        q1: '', q2: '', q3: '', q4: '', q5: '', q6: '', q7: '',
        q8: '', q9: '', q10: '', q11: '', q12: '', q13: '', q14: ''
    };

    @track roleOptions = [];
    @track companyTypeOptions = [];
    @track clientDurationOptions = [];
    @track productOptions = [];
    @track ratingOptions = [
        { label: '1 - Strongly Disagree', value: '1 - Strongly Disagree' },
        { label: '2 - Disagree', value: '2 - Disagree' },
        { label: '3 - Neutral', value: '3 - Neutral' },
        { label: '4 - Agree', value: '4 - Agree' },
        { label: '5 - Strongly Agree', value: '5 - Strongly Agree' },
        { label: 'N/A', value: 'N/A' }
    ];

    @track satisfactionOptions = [
        { label: '1 - Very Dissatisfied', value: '1 - Very Dissatisfied' },
        { label: '2 - Dissatisfied', value: '2 - Dissatisfied' },
        { label: '3 - Neutral', value: '3 - Neutral' },
        { label: '4 - Satisfied', value: '4 - Satisfied' },
        { label: '5 - Very Satisfied', value: '5 - Very Satisfied' }
    ];

    @track recommendOptions = [
        { label: '1 - Very Dissatisfied', value: '1 - Very Dissatisfied' },
        { label: '2 - Dissatisfied', value: '2 - Dissatisfied' },
        { label: '3 - Neutral', value: '3 - Neutral' },
        { label: '4 - Satisfied', value: '4 - Satisfied' },
        { label: '5 - Very Satisfied', value: '5 - Very Satisfied' }
    ];
    get backgroundImageStyle() {
        return `background-image: url(${welcomeImage});`;
    }
    get backgroundImageStyleThank() {
        return `background-image: url(${ThankyouPage}); background-size: cover; background-position: center;`;
    }

    // Get object info for Survey__c
    @wire(getObjectInfo, { objectApiName: SURVEY_OBJECT })
    objectInfo;

    // Fetch picklist values for Primary_Product__c
    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: PRIMARY_PRODUCT_FIELD })
    wiredProductOptions({ error, data }) {
        if (data) {
            this.productOptions = data.values.map(entry => ({
                label: entry.label,
                value: entry.value
            }));
        } else if (error) {
            this.showToast('Error', 'Failed to load product options: ' + error.body.message, 'error');
        }
    }

    // Fetch picklist values for Role__c
    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: ROLE_FIELD })
    wiredRoleOptions({ error, data }) {
        if (data) {
            this.roleOptions = data.values.map(entry => ({
                label: entry.label,
                value: entry.value
            }));
        } else if (error) {
            this.showToast('Error', 'Failed to load role options: ' + error.body.message, 'error');
        }
    }

    // Fetch picklist values for Company_Type__c
    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: COMPANY_TYPE_FIELD })
    wiredCompanyTypeOptions({ error, data }) {
        if (data) {
            this.companyTypeOptions = data.values.map(entry => ({
                label: entry.label,
                value: entry.value
            }));
        } else if (error) {
            this.showToast('Error', 'Failed to load company type options: ' + error.body.message, 'error');
        }
    }

    // Fetch picklist values for Client_Duration__c
    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: CLIENT_DURATION_FIELD })
    wiredClientDurationOptions({ error, data }) {
        if (data) {
            this.clientDurationOptions = data.values.map(entry => ({
                label: entry.label,
                value: entry.value
            }));
        } else if (error) {
            this.showToast('Error', 'Failed to load client duration options: ' + error.body.message, 'error');
        }
    }

    // Fetch survey data on component load
    connectedCallback() {
        const uniqueId = this.getUrlParam('UNI');
        console.log('uniqueId: ', uniqueId);
        if (uniqueId) {
            getSurveyByUniqueId({ uniqueId })
                .then(result => {
                    if (result) {
                        this.surveyId = result.Id;
                        if (result.Status__c === 'Submitted') {
                            this.showWelcome = false;
                            this.showSurvey = false;
                            this.showThankYou = true;
                            this.surveyAlreadySubmitted = true;
                        } else {
                            this.showWelcome = true;
                            this.showThankYou = false;
                            // Prepopulate respondent info
                            this.respondentInfo = {
                                name: '',
                                email: result.Email_Id__c || '',
                                phone: result.Phone__c || '',
                                companyName: result.Account_Name__c || '',
                                role: result.Role__c || '',
                                companyType: result.Company_Type__c || '',
                                products: result.Primary_Product__c || '',
                                clientDuration: result.Client_Duration__c || '',
                                roleOther: result.Role_Title_Others__c || '',
                                cTOther: result.Company_Type_Others__c || '',
                                otp: result.Otp_Verification__c || '',
                            };
                            /*  if (this.respondentInfo.roleOther == 'Other - Please Specify') {
                                  this.showRoleOther = true;
                              } else {
                                  this.showRoleOther = false;
                              }
                              if (this.respondentInfo.cTOther == 'Other - Please Specify') {
                                  this.showCTOther = true;
                              } else {
                                  this.showCTOther = false;
                              }*/
                            // Disable fields with existing values
                            this.respondentInfoDisabled = {
                                name: !!result.Name,
                                email: !!result.Email_Id__c,
                                phone: !!result.Phone__c,
                                companyName: !!result.Account_Name__c,
                                role: !!result.Role__c,
                                companyType: !!result.Company_Type__c,
                                products: !!result.Primary_Product__c,
                                clientDuration: !!result.Client_Duration__c
                            };
                            // Prepopulate survey responses if they exist
                            /*  this.surveyResponses = {
                                  q1: result.A_Understanding_Your_Needs_Question_1__c || '',
                                  q2: result.A_Understanding_Your_Needs_Question_2__c || '',
                                  q3: result.Product_Knowledge_Expertise_Question_1__c || '',
                                  q4: result.Product_Knowledge_Expertise_Question2__c || '',
                                  q5: result.Communication_Responsiveness_Question1__c || '',
                                  q6: result.Communication_Responsiveness_Question2__c || '',
                                  q7: result.Communication_Responsiveness_Question3__c || '',
                                  q8: result.Relationship_Management_Question_1__c || '',
                                  q9: result.Relationship_Management_Question_2__c || '',
                                  q10: result.Negotiation_Value_Proposition_Question_1__c || '',
                                  q11: result.Negotiation_Value_Proposition_Question_2__c || '',
                                  q12: result.Problem_Solving_Support_Question_1__c || '',
                                  q13: result.Overall_Satisfaction_Question_1__c || '',
                                  q14: result.Overall_Satisfaction_Question_2__c || ''
                              };*/
                        }
                    } else {
                        this.showToast('Error', 'Survey not found for the provided ID.', 'error');
                    }
                })
                .catch(error => {
                    this.showToast('Error', 'Error loading survey: ' + error.body.message, 'error');
                });
        } else {
            this.showToast('Error', 'No survey ID provided in the URL.', 'error');
        }
    }
    closeModal() {
        this.showOtpModal = false;
        this.showWelcome = true;
        this.resetOtpFields();
    }
    resetOtpFields() {
        this.otpValue = '';
    }
    @track otpValue = '';
    @track showOtpModal = false;
    handleOtpChange(event) {
        this.otpValue = event.target.value;

        // Only allow numeric input
        const numericValue = this.otpValue.replace(/[^0-9]/g, '');
        if (numericValue !== this.otpValue) {
            this.otpValue = numericValue;
            event.target.value = numericValue;
        }
    }

    verifyOtp() {
        if (!this.otpValue) {
            this.showToast('Error', 'Please enter valid OTP and try again!', 'error');
            return;
        }
        // Here you would typically call an Apex method to verify OTP
        // For demo purposes, we'll simulate verification
        this.simulateOtpVerification();
    }
    simulateOtpVerification() {
        if (this.otpValue == this.respondentInfo.otp) {
            this.showToast('Success', 'OTP verification is successfull!', 'success');
            this.showWelcome = false;
            this.showSurvey = true;
            this.showThankYou = false;
            this.showOtpModal = false;
        } else {
            this.showToast('Error', 'Please enter valid OTP and try again!', 'error');
        }
    }

    startSurvey() {
        this.showWelcome = false;
        this.showSurvey = false;
        this.showThankYou = false;
        this.showOtpModal = true;
    }
    @track showRoleOther;
    @track showCTOther;
    handleInputChange(event) {
        const field = event.target.name;
        this.respondentInfo[field] = event.target.value;
        if (field == 'role') {
            if (event.target.value == 'Other - Please Specify') {
                this.showRoleOther = true;
            } else {
                this.showRoleOther = false;
            }
        }
        if (field == 'companyType') {
            if (event.target.value == 'Other - Please Specify') {
                this.showCTOther = true;
            } else {
                this.showCTOther = false;
            }
        }
    }

    handleSurveyChange(event) {
        const field = event.target.name;
        this.surveyResponses[field] = event.target.value;
    }

    submitSurvey() {
        // Validate required fields
        let isValid = true;
        let errorMessage = 'Please complete all required fields:';

        // Check Name field
        if (!this.respondentInfo.name) {
            isValid = false;
            errorMessage += '\n- Name';
        }

        // Check all survey questions
        const questions = Object.keys(this.surveyResponses);
        const missingQuestions = questions.filter(q => !this.surveyResponses[q]);

        if (missingQuestions.length > 0) {
            isValid = false;
            missingQuestions.forEach(q => {
                errorMessage += `\n- Question ${q.replace('q', '')}`;
            });
        }

        if (!isValid) {
            this.showToast('Error', errorMessage, 'error');
            return;
        }

        // If validation passes, proceed with survey submission
        updateSurvey({
            surveyId: this.surveyId,
            surveyResponses: this.surveyResponses,
            respondentInfo: this.respondentInfo
        })
            .then(() => {
                this.showWelcome = false;
                this.showSurvey = false;
                this.showThankYou = true;
                this.surveyAlreadySubmitted = false;
                this.showToast('Success', 'Survey submitted successfully!', 'success');
            })
            .catch(error => {
                this.showToast('Error', 'Error submitting survey: ' + error.body.message, 'error');
            });
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(evt);
    }

    getUrlParam(paramName) {
        const urlParams = new URLSearchParams(window.location.search);
        console.log(urlParams);
        return urlParams.get(paramName);
    }
}