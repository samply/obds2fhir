package de.samply.obds2fhir;

import org.apache.http.HttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.conn.ssl.NoopHostnameVerifier;
import org.apache.http.conn.ssl.SSLContextBuilder;
import org.apache.http.conn.ssl.TrustAllStrategy;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.security.KeyManagementException;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;
import java.util.concurrent.TimeUnit;

public class Util {
    private static final Logger logger = LoggerFactory.getLogger(Util.class);

    public static CloseableHttpClient getHttpClient(Boolean sslVerification){
        CloseableHttpClient httpclient;
        if (!sslVerification){//experimental feature, do not set ssl_certificate_validation=false
            try {
                httpclient = HttpClients.custom()
                        .setSSLContext(new SSLContextBuilder().loadTrustMaterial(null, TrustAllStrategy.INSTANCE).build())
                        .setSSLHostnameVerifier(NoopHostnameVerifier.INSTANCE).build();
            } catch (NoSuchAlgorithmException | KeyManagementException | KeyStoreException e) {
                throw new RuntimeException(e);
            }
        }
        else {
            httpclient = HttpClients.createDefault();
        }
        return httpclient;
    }

    public static boolean checkConnections(String servicename, String URL, boolean waitForConnection) {
        CloseableHttpClient httpclient;
        httpclient = getHttpClient(Boolean.parseBoolean(System.getenv().getOrDefault("SSL_CERTIFICATE_VALIDATION","")));
        HttpResponse httpResponse;
        HttpGet httpGetRequest;
        if (URL != null && URL.startsWith("http")) {
            httpGetRequest = new HttpGet(URL);
            String encoding = Base64.getEncoder().encodeToString(System.getenv().getOrDefault("STORE_AUTH","").getBytes());
            httpGetRequest.addHeader("Authorization", "Basic " + encoding);
            try {
                httpResponse = httpclient.execute(httpGetRequest);
                if (httpResponse.getStatusLine().getReasonPhrase().equals("OK") || httpResponse.getStatusLine().getStatusCode()==200) {
                    logger.info(servicename + " is accessible: " + URL);
                    return true;
                }
                else {
                    if (waitForConnection){
                        logger.info("Waiting for service " + servicename + ", trying again...");
                        TimeUnit.SECONDS.sleep(2);
                        return checkConnections(servicename,URL,waitForConnection);
                    }
                    logger.info(servicename + " is NOT accessible: " + URL + httpResponse.getStatusLine());
                }
                httpclient.close();
            } catch (IOException | InterruptedException e) {
                logger.warn("Exception while trying to access " + servicename + " at " + URL);
                if (waitForConnection){//if true, then recursively execute again
                    logger.info("Waiting for service "+servicename+" , trying again...");
                    try {
                        TimeUnit.SECONDS.sleep(5);
                    } catch (InterruptedException ex) {
                        logger.error("InterruptedException while waiting" + e);
                    }
                    return checkConnections(servicename,URL,waitForConnection);
                }
            }
        }
        else {
            logger.info(servicename + " url not specified. Skipping relevant processes");
        }
        return false;
    }

    public static int getFileVersion(String xmlContent) throws IllegalArgumentException {
        if (xmlContent.contains("<ADT_GEKID")) {
            return 2;
        } else if (xmlContent.contains("<oBDS")) {
            return 3;
        } else {
            int maxLength = xmlContent.length() < 200 ? xmlContent.length() : 200;
            throw new IllegalArgumentException("Error: File does not contain oBDS or ADT/GEKID  " + xmlContent.substring(0, maxLength));
        }
    }

}
