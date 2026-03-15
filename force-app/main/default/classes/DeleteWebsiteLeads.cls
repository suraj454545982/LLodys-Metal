public class DeleteWebsiteLeads implements Queueable {

    private List<Id> leadIds;

    public DeleteWebsiteLeads(List<Id> leadIds) {
        this.leadIds = leadIds;
    }

    public void execute(QueueableContext context) {

        if (leadIds == null || leadIds.isEmpty()) return;

        List<Lead> leadsToDelete = [
            SELECT Id FROM Lead WHERE Id IN :leadIds
        ];

        if (!leadsToDelete.isEmpty()) {
            delete leadsToDelete;
        }
    }
}