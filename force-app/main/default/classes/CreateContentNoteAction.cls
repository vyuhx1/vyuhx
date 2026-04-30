public class CreateContentNoteAction {

    public class Request {
        @InvocableVariable(label='Visit Id' description='Id of the Visit record to link the note to' required=true)
        public String visitId;

        @InvocableVariable(label='Note Body' description='Plain text content of the note' required=true)
        public String noteBody;

        @InvocableVariable(label='Note Title' description='Title of the note')
        public String noteTitle;
    }

    public class Result {
        @InvocableVariable(label='Content Document Id' description='Id of the created ContentNote/ContentDocument')
        public String contentDocumentId;
    }

    @InvocableMethod(
        label='Create Content Note on Visit'
        description='Creates a ContentNote with the given text and links it to the specified Visit record via ContentDocumentLink.'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result res = new Result();

            if (String.isBlank(req.visitId) || String.isBlank(req.noteBody)) {
                results.add(res);
                continue;
            }

            String title = String.isBlank(req.noteTitle) ? 'Visit Note' : req.noteTitle;

            ContentNote cn = new ContentNote();
            cn.Title   = title;
            // ContentNote.Content requires HTML-escaped, Base64-encoded text
            cn.Content = Blob.valueOf(req.noteBody.escapeHtml4());
            insert cn;

            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = cn.Id;
            cdl.LinkedEntityId    = req.visitId;
            cdl.ShareType         = 'V';
            cdl.Visibility        = 'AllUsers';
            insert cdl;

            res.contentDocumentId = cn.Id;
            results.add(res);
        }

        return results;
    }
}