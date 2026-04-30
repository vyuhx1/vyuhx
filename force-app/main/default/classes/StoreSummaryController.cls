/**
 * StoreSummaryController
 * ──────────────────────────────────────────────────────────────────────────
 * Invokes the "Store_Agent_Summary" Einstein Prompt Template for a given
 * RetailStore record.  The template internally calls StoreContextForPromptAction
 * (apex data provider) which fetches the store, its Sites__c records, completed
 * Visits, and ContentNote summaries, then passes that block to the LLM.
 *
 * Returns a SummaryResult with the store name and the raw LLM response text.
 * The LWC (storeSummaryCard) parses the structured plain-text sections.
 */
public with sharing class StoreSummaryController {

    // ── Return type ────────────────────────────────────────────────────────

    public class SummaryResult {
        @AuraEnabled public String storeId;
        @AuraEnabled public String storeName;
        @AuraEnabled public String summary;   // raw text from the LLM
    }

    // ── AuraEnabled method ─────────────────────────────────────────────────

    @AuraEnabled
    public static SummaryResult generateSummary(Id storeId) {

        // 1. Verify the record is accessible and get the display name
        List<RetailStore> stores = [
            SELECT Id, Name
            FROM   RetailStore
            WHERE  Id = :storeId
            LIMIT  1
        ];
        if (stores.isEmpty()) {
            throw new AuraHandledException('Retail store not found: ' + storeId);
        }
        RetailStore rs = stores[0];

        // 2. Build the input map — SObject inputs require Map<String,String>{'id' => recordId}
        Map<String, String> storeIdMap = new Map<String, String>();
        storeIdMap.put('id', String.valueOf(storeId));

        ConnectApi.WrappedValue storeVal = new ConnectApi.WrappedValue();
        storeVal.value = storeIdMap;

        Map<String, ConnectApi.WrappedValue> valueMap = new Map<String, ConnectApi.WrappedValue>();
        valueMap.put('Input:RetailStore', storeVal);

        // 3. Build the generations input — inputParams + additionalConfig go inside the object
        ConnectApi.EinsteinPromptTemplateGenerationsInput genInput =
            new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        genInput.isPreview    = false;
        genInput.inputParams  = valueMap;

        genInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        genInput.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';

        // 4. Call the service — two-argument overload only
        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation resp;
        try {
            resp = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                'Store_Agent_Summary',  // template developerName
                genInput                // all inputs + config
            );
        } catch (Exception e) {
            throw new AuraHandledException(
                'Prompt template call failed: ' + e.getMessage()
            );
        }

        // 4. Extract the generated text
        if (resp == null
                || resp.generations == null
                || resp.generations.isEmpty()) {
            throw new AuraHandledException('The AI model returned no output.');
        }

        SummaryResult result = new SummaryResult();
        result.storeId   = String.valueOf(storeId);
        result.storeName = rs.Name;
        result.summary   = resp.generations[0].text;
        return result;
    }
}