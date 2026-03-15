public class UUIDGenerator {
    public static String generateUUID() {
        String uuid = '';
        String chars = '0123456789abcdef';
        Integer[] sections = new Integer[]{8,4,4,4,12};
            
            for(Integer i=0; i<sections.size(); i++) {
                for(Integer j=0; j<sections[i]; j++) {
                    Integer randomInt = Crypto.getRandomInteger();
                    Integer index = Math.mod(Math.abs(randomInt), chars.length());
                    uuid += chars.substring(index, index+1);
                }
                if (i < sections.size() - 1) {
                    uuid += '-';
                }
            }
        return uuid;
    }
    public static String generateOTP() {
        String digits = '0123456789';
        String otp = '';
        
        for (Integer i = 0; i < 6; i++) {
            Integer randomInt = Crypto.getRandomInteger();
            Integer index = Math.mod(Math.abs(randomInt), digits.length());
            otp += digits.substring(index, index + 1);
        }
        
        return otp;
    }
    
}