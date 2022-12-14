package de.samply.adt2fhir;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import de.pseudonymisierung.mainzelliste.client.*;
import java.io.IOException;
import java.net.InetAddress;
import java.net.URISyntaxException;
import java.net.UnknownHostException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import net.sf.saxon.expr.XPathContext;
import net.sf.saxon.lib.ExtensionFunctionCall;
import net.sf.saxon.lib.ExtensionFunctionDefinition;
import net.sf.saxon.om.Sequence;
import net.sf.saxon.om.StructuredQName;
import net.sf.saxon.value.SequenceType;
import net.sf.saxon.value.StringValue;
import org.apache.commons.codec.digest.DigestUtils;
import org.apache.http.HttpResponse;
import org.apache.http.NameValuePair;
import org.apache.http.client.entity.UrlEncodedFormEntity;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.message.BasicNameValuePair;
import org.apache.http.util.EntityUtils;

public class PatientPseudonymizer extends ExtensionFunctionDefinition {
    private String mainzelliste_url;
    private boolean anonymize=false;
    private MainzellisteConnection mainzellisteConnection;
    private Session session;
    private AddPatientToken token;
    private String addPatientToken;
    private CloseableHttpClient httpclient;
    private String salt;

    @Override
    public net.sf.saxon.value.SequenceType[] getArgumentTypes() {
        return new net.sf.saxon.value.SequenceType[] {
                net.sf.saxon.value.SequenceType.SINGLE_STRING,
                net.sf.saxon.value.SequenceType.SINGLE_STRING,
                net.sf.saxon.value.SequenceType.SINGLE_STRING,
                net.sf.saxon.value.SequenceType.SINGLE_STRING,
                net.sf.saxon.value.SequenceType.SINGLE_STRING,
                net.sf.saxon.value.SequenceType.SINGLE_STRING };
    }

    @Override
    public StructuredQName getFunctionQName() {
        return new StructuredQName("hash", "java:de.samply.adt2fhir", "pseudonymize");
    }

    @Override
    public net.sf.saxon.value.SequenceType getResultType(net.sf.saxon.value.SequenceType[] arg0) {
        return SequenceType.SINGLE_STRING;
    }

    @Override
    public ExtensionFunctionCall makeCallExpression() {
        return new ExtensionFunctionCall() {

            @Override
            public Sequence call(XPathContext ctx, Sequence[] args) {
                String output = "";
                String gender = args[0].iterate().next().getStringValue();
                String prename = args[1].iterate().next().getStringValue();
                String surname = args[2].iterate().next().getStringValue();
                String formername = args[3].iterate().next().getStringValue();
                String brithdate = args[4].iterate().next().getStringValue();
                String identifier = args[5].iterate().next().getStringValue();

                if (anonymize) {
                    output = DigestUtils.sha256Hex(gender + prename + surname + formername + brithdate + identifier + salt).substring(32);
                } else {
                    try {
                        output=pseudonymizationCall(gender, prename, surname, formername, brithdate, identifier);
                    } catch (URISyntaxException | MainzellisteNetworkException | InvalidSessionException | IOException e) {
                        e.printStackTrace();
                    }
                }
                return StringValue.makeStringValue(output);
            }

        };
    }

    private String pseudonymizationCall(String gender, String prename, String surname, String formername, String brithdate, String identifier) throws URISyntaxException, MainzellisteNetworkException, InvalidSessionException, IOException {
        String pseudonym="";
        String[] brithdateParts = brithdate.split("[.]");
        this.addPatientToken = session.getToken(token);
        HttpPost httppost = createHttpPost(prename, surname, formername, brithdateParts[0], brithdateParts[1], brithdateParts[2], gender);
        HttpResponse response = httpclient.execute(httppost);
        if (response.getStatusLine().getStatusCode()==401) {
            createMainzellisteSession();
            this.addPatientToken = session.getToken(token);
            response = httpclient.execute(new HttpPost(mainzelliste_url+"/patients?tokenId="+addPatientToken));
            System.out.println("Creating new session");
        }
        if (response.getStatusLine().getStatusCode()==400){
            this.httpclient = HttpClients.createDefault();
            httppost = createHttpPost(preprocessIDAT(prename), preprocessIDAT(surname), preprocessIDAT(formername), brithdateParts[0], brithdateParts[1], brithdateParts[2], gender);
            response = httpclient.execute(httppost);
            System.out.println("\u001B[A"+"\u001B[100C" + "Unallowed character in patient "+ identifier + " ... autocorrected\n");
        }
        if (response.getStatusLine().getStatusCode()!=201) {
            System.out.println("ERROR - Pseudonymization response: " +  response.getStatusLine().getStatusCode());
        }
        String responseBody = EntityUtils.toString(response.getEntity(), StandardCharsets.UTF_8);

        JsonArray ids = new Gson ().fromJson(responseBody, JsonArray.class);
        if(!ids.isEmpty()){
            JsonObject id = ids.get(0).getAsJsonObject();
            pseudonym=id.getAsJsonPrimitive("idString").getAsString();
        }
        return pseudonym;
    }

    public void initialize (ConfigReader configReader, boolean pseudonymize){
        if (pseudonymize){
            this.anonymize=false;
            this.mainzelliste_url=configReader.getMainzelliste_url();
            String mainzelliste_apikey=configReader.getMainzelliste_apikey();
            try {
                this.mainzellisteConnection = new MainzellisteConnection(mainzelliste_url, mainzelliste_apikey);
                this.token = new AddPatientToken();
                AuditTrailLog auditTrailLog = new AuditTrailLog();
                auditTrailLog.setUsername("adt2fhir");
                auditTrailLog.setRemoteSystem(String.valueOf(InetAddress.getLocalHost()));
                auditTrailLog.setReasonForChange("Add Patient");
                this.token.setAuditTrailLog(auditTrailLog);
                this.token.addIdType(configReader.getIdtype());
                this.httpclient = HttpClients.createDefault();
                createMainzellisteSession();
            } catch (URISyntaxException | MainzellisteNetworkException | InvalidSessionException | UnknownHostException e) {
                throw new RuntimeException(e);
            }
        }
        else {
            this.anonymize=true;
            this.salt=configReader.getSalt();
        }
    }

    private void createMainzellisteSession() throws InvalidSessionException, MainzellisteNetworkException {
        this.session = mainzellisteConnection.createSession();
    }

    private HttpPost createHttpPost (String prename, String surname, String formername, String brithday, String brithmonth, String brithyear, String gender) {
        HttpPost httppost= new HttpPost(mainzelliste_url+"/patients?tokenId="+addPatientToken);
        httppost.addHeader("content-type", "application/x-www-form-urlencoded");
        httppost.addHeader("mainzellisteApiVersion", "3.2");
        List<NameValuePair> idat = new ArrayList<>();
        idat.add(new BasicNameValuePair("vorname", prename));
        idat.add(new BasicNameValuePair("nachname", surname));
        idat.add(new BasicNameValuePair("fruehere_Namen", formername));
        idat.add(new BasicNameValuePair("geburtstag", brithday));
        idat.add(new BasicNameValuePair("geburtsmonat", brithmonth));
        idat.add(new BasicNameValuePair("geburtsjahr", brithyear));
        idat.add(new BasicNameValuePair("gender", gender));
        idat.add(new BasicNameValuePair("sureness", "true"));

        httppost.setEntity(new UrlEncodedFormEntity(idat, StandardCharsets.UTF_8));
        return httppost;
    }

    private String preprocessIDAT (String name){
        return name.replaceAll("[^a-zA-ZäÄöÖüÜßéÉ]", "");
    }
}
