@isTest
public class UUIDGeneratorTest {

    @isTest
    public static void testGenerateUUID_NotNullAndCorrectFormat_Positive() {
        // Act
        String uuid = UUIDGenerator.generateUUID();

        // Assert: Not null or empty
        System.assertNotEquals(null, uuid, 'UUID should not be null');
        System.assertNotEquals('', uuid, 'UUID should not be empty');

        // Assert: Correct format (8-4-4-4-12)
        List<String> parts = uuid.split('-');
        System.assertEquals(5, parts.size(), 'UUID should have 5 parts separated by hyphens');
        System.assertEquals(8, parts[0].length(), 'First part should be 8 characters');
        System.assertEquals(4, parts[1].length(), 'Second part should be 4 characters');
        System.assertEquals(4, parts[2].length(), 'Third part should be 4 characters');
        System.assertEquals(4, parts[3].length(), 'Fourth part should be 4 characters');
        System.assertEquals(12, parts[4].length(), 'Fifth part should be 12 characters');
    }

    @isTest
    public static void testGenerateUUID_UniqueValues() {
        // Act
        String uuid1 = UUIDGenerator.generateUUID();
        String uuid2 = UUIDGenerator.generateUUID();

        // Assert: UUIDs should be different
        System.assertNotEquals(uuid1, uuid2, 'Each UUID should be unique');
    }
}