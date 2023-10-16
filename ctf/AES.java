Solution for CTF Mobile Challenge 3:

Step 1: Decompile APK using jdax https://github.com/skylot/jadx
Step 2: Copy the Encrypted flag : +dj95PdlPDEVVa2pioN07g==
Step 3: Check for the Encryption and Decryption Key in the asset folder of the application package.
Step 4: Review the encryption algorithm. Consrtuct decryption code to get the flag. Plese find the below "AES.java" code to decrypt the flag.
Step 5: Run the AES.java in Java online java compiler. https://www.tutorialspoint.com/compile_java_online.php. The result will proivde the flag.
==============================================================================================================================================================================
//AES.java code code decrypt the flag.


import java.io.UnsupportedEncodingException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Arrays;
import java.util.Base64;
 
import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;
 
public class AES {
 
    private static SecretKeySpec secretKey;
    private static byte[] key;

public static void main(String[] args) 
{
    final String secretKey = "TryPBKDF2"; 
     
	String encryptedString = "+dj95PdlPDEVVa2pioN07g==" ;
    String decryptedString = AES.decrypt(encryptedString, secretKey) ;
     
    System.out.println(encryptedString);
    System.out.println(decryptedString);
}
 
    public static void setKey(String myKey) 
    {
        MessageDigest sha = null;
        try {
            key = myKey.getBytes("UTF-8");
            sha = MessageDigest.getInstance("SHA-1");
            key = sha.digest(key);
            key = Arrays.copyOf(key, 16); 
            secretKey = new SecretKeySpec(key, "AES");
        } 
        catch (NoSuchAlgorithmException e) {
            e.printStackTrace();
        } 
        catch (UnsupportedEncodingException e) {
            e.printStackTrace();
        }
    }
 
    
    public static String decrypt(String strToDecrypt, String secret) 
    {
        try
        {
            setKey(secret);
            Cipher cipher = Cipher.getInstance("AES/ECB/PKCS5PADDING");
            cipher.init(Cipher.DECRYPT_MODE, secretKey);
            return new String(cipher.doFinal(Base64.getDecoder().decode(strToDecrypt)));
        } 
        catch (Exception e) 
        {
            System.out.println("Error while decrypting: " + e.toString());
        }
        return null;
    }
}

============================================================================================================================================================================




