public class MetaConversionsAPI {

    // Replace with your actual values

    static final String ACCESS_TOKEN = 'EAAKMzBqVVHMBOZCIZCxj3adqZBK3tjrnsZAaK1eDAZAMF6PbGM8WM5ZCZCpuZCikPjn2vNoA3E2P0nxBNzWvoaO6ACE5us5QWFW0HoHEM2vWylpQAqGtZAhBFZCJBeQziZB57Iq26RpKqnXjZABHSrxqn7EkL0USLF13eZCqT9AgOi3bTguu64bHiaEqWFpkZCKU5OO0GvrQZDZD';

    static final String PIXEL_ID = '4161753057477533';

    public class UserData {

        public List<String> em;

        public List<String> ph;

    }

    public class CustomData {

        public String currency1 = 'INR';

        public Decimal value = 0;

    }

    public class EventData {

        public String event_name;

        public Long event_time;

        public String action_source = 'website';

        public String event_source_url;

        public UserData user_data;

        public CustomData custom_data;

    }

    public class Payload {

        public List<EventData> data;

    }

    public static void sendLeadToMeta(String email, String phone, String eventName, String sourceUrl, Long timestamp) {

        // Hash email and phone using SHA256

        String hashedEmail = hashSHA256(email.toLowerCase().trim());

        String hashedPhone = hashSHA256(phone.toLowerCase().trim());

        UserData userData = new UserData();

        userData.em = new List<String>{ hashedEmail };

        userData.ph = new List<String>{ hashedPhone };

        EventData eventData = new EventData();

        eventData.event_name = eventName;

        eventData.event_time = timestamp;

        eventData.event_source_url = sourceUrl;

        eventData.user_data = userData;

        eventData.custom_data = new CustomData();

        Payload payload = new Payload();

        payload.data = new List<EventData>{ eventData };

        // Prepare the HTTP request

        Http http = new Http();

        HttpRequest request = new HttpRequest();

        request.setEndpoint('https://graph.facebook.com/v18.0/' + PIXEL_ID + '/events?access_token=' + ACCESS_TOKEN);

        request.setMethod('POST');

        request.setHeader('Content-Type', 'application/json');

        request.setBody(JSON.serialize(payload));

        // Send the request

        HttpResponse response = http.send(request);

        System.debug('Response: ' + response.getBody());

    }

    private static String hashSHA256(String input) {

        Blob inputBlob = Blob.valueOf(input);

        Blob hash = Crypto.generateDigest('SHA-256', inputBlob);

        return EncodingUtil.convertToHex(hash);

    }

}