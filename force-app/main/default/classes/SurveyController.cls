/**
* @File Name : SurveyController.cls
* @Description : Survey from customer
* @Author : Gowsic N
* @Last Modified By :
* @Last Modified On : May 23, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | May 23, 2025 |   | Initial Version
**/

public without sharing class SurveyController {
    @AuraEnabled(cacheable=true)
    public static Survey__c getSurveyByUniqueId(String uniqueId) {
        try {
            return [
                SELECT Id, Unique_ID__c, Status__c, Name, Email_Id__c, Phone__c,ClientDurationOptions__c,Role_Title_Others__c,
                       Account_Name__c, Primary_Product__c,Role__c,Company_Type__c,Company_Type_Others__c,otp_verification__c,
                       A_Understanding_Your_Needs_Question_1__c, A_Understanding_Your_Needs_Question_2__c,
                       Product_Knowledge_Expertise_Question_1__c, Product_Knowledge_Expertise_Question2__c,
                       Communication_Responsiveness_Question1__c, Communication_Responsiveness_Question2__c,
                       Communication_Responsiveness_Question3__c, Relationship_Management_Question_1__c,
                       Relationship_Management_Question_2__c, Negotiation_Value_Proposition_Question_1__c,
                       Negotiation_Value_Proposition_Question_2__c, Problem_Solving_Support_Question_1__c,
                       Overall_Satisfaction_Question_1__c, Overall_Satisfaction_Question_2__c
                FROM Survey__c 
                WHERE Unique_ID__c = :uniqueId 
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching survey: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateSurvey(String surveyId, Map<String, String> surveyResponses, Map<String, String> respondentInfo) {
      //  try {
            Survey__c survey = new Survey__c(Id = surveyId);
            // Update respondent info
            survey.Name = respondentInfo.get('name');
            survey.Email_Id__c = respondentInfo.get('email');
            survey.Phone__c = respondentInfo.get('phone');
            survey.Account_Name__c = respondentInfo.get('companyName');
            survey.Primary_Product__c = respondentInfo.get('products');
            // Add custom fields for role, companyType, clientDuration if they exist in Survey__c
             survey.Role__c = respondentInfo.get('role');
             survey.Company_Type__c = respondentInfo.get('companyType');
             survey.ClientDurationOptions__c = respondentInfo.get('clientDuration');
             survey.Role_Title_Others__c = respondentInfo.get('roleOther');
             survey.Company_Type_Others__c = respondentInfo.get('cTOther');

            // Update survey responses
            survey.A_Understanding_Your_Needs_Question_1__c = surveyResponses.get('q1');
            survey.A_Understanding_Your_Needs_Question_2__c = surveyResponses.get('q2');
            survey.Product_Knowledge_Expertise_Question_1__c = surveyResponses.get('q3');
            survey.Product_Knowledge_Expertise_Question2__c = surveyResponses.get('q4');
            survey.Communication_Responsiveness_Question1__c = surveyResponses.get('q5');
            survey.Communication_Responsiveness_Question2__c = surveyResponses.get('q6');
            survey.Communication_Responsiveness_Question3__c = surveyResponses.get('q7');
            survey.Relationship_Management_Question_1__c = surveyResponses.get('q8');
            survey.Relationship_Management_Question_2__c = surveyResponses.get('q9');
            survey.Negotiation_Value_Proposition_Question_1__c = surveyResponses.get('q10');
            survey.Negotiation_Value_Proposition_Question_2__c = surveyResponses.get('q11');
            survey.Problem_Solving_Support_Question_1__c = surveyResponses.get('q12');
            survey.Overall_Satisfaction_Question_1__c = surveyResponses.get('q13');
            survey.Overall_Satisfaction_Question_2__c = surveyResponses.get('q14');
            survey.Status__c = 'Submitted';

            update survey;
       /* } catch (Exception e) {
            throw new AuraHandledException('Error updating survey: ' + e.getMessage());
        }*/
    }

  
}