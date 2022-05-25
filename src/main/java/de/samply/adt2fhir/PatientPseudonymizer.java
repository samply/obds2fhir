package de.samply.adt2fhir;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import de.pseudonymisierung.mainzelliste.client.*;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.URISyntaxException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import net.sf.saxon.expr.XPathContext;
import net.sf.saxon.lib.ExtensionFunctionCall;
import net.sf.saxon.lib.ExtensionFunctionDefinition;
import net.sf.saxon.om.Sequence;
import net.sf.saxon.om.StructuredQName;
import net.sf.saxon.trans.XPathException;
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
import org.apache.http.protocol.HTTP;
import org.apache.http.util.EntityUtils;

public class PatientPseudonymizer extends ExtensionFunctionDefinition {
    private String mainzelliste_url;
    private String mainzelliste_apikey;
    private boolean anonymize=false;
    private MainzellisteConnection mainzellisteConnection;
    private Session session;
    private AddPatientToken token;
    private String addPatientToken;
    private CloseableHttpClient httpclient;

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
            public Sequence call(XPathContext ctx, Sequence[] args) throws XPathException {
                String output = "";
                String gender = args[0].iterate().next().getStringValue();
                String prename = args[1].iterate().next().getStringValue();
                String surname = args[2].iterate().next().getStringValue();
                String birthname = args[3].iterate().next().getStringValue();
                String brithdate = args[4].iterate().next().getStringValue();
                String identifier = args[5].iterate().next().getStringValue();

                if (anonymize) {
                    output = DigestUtils.sha256Hex(gender + prename + surname + birthname + brithdate + identifier).substring(32);
                } else {
                    try {
                        output=pseudonymizationCall(gender, prename, surname, birthname, brithdate, identifier);
                    } catch (URISyntaxException | MainzellisteNetworkException | InvalidSessionException | IOException e) {
                        e.printStackTrace();
                    }
                }
                return StringValue.makeStringValue(output);
            }

        };
    }

    private String pseudonymizationCall(String gender, String prename, String surname, String birthname, String brithdate, String identifier) throws URISyntaxException, MainzellisteNetworkException, InvalidSessionException, IOException {
        String pseudonym="";
        String[] brithdateParts = brithdate.split("[.]");
        this.addPatientToken = session.getToken(token);
        HttpPost httppost = createHttpPost(prename, surname, birthname, brithdateParts[0], brithdateParts[1], brithdateParts[2]);
        HttpResponse response = httpclient.execute(httppost);
        if (response.getStatusLine().getStatusCode()==401) {
            createMainzellisteConnection();
            this.addPatientToken = session.getToken(token);
            response = httpclient.execute(new HttpPost(mainzelliste_url+"/patients?tokenId="+addPatientToken));
            System.out.println("Creating new session");
        }
        if (response.getStatusLine().getStatusCode()==400){
            this.httpclient = HttpClients.createDefault();
            httppost = createHttpPost(preprocessIDAT(prename), preprocessIDAT(surname), preprocessIDAT(birthname), brithdateParts[0], brithdateParts[1], brithdateParts[2]);
            response = httpclient.execute(httppost);
            System.out.println("\u001B[A"+"\u001B[100C" + "Unallowed character in patient "+ identifier + " ... autocorrected");
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

    public void initialize (ConfigReader configReader){
        this.mainzelliste_url=configReader.getMainzelliste_url();
        this.mainzelliste_apikey=configReader.getMainzelliste_apikey();
        if (mainzelliste_apikey.isEmpty()){
            this.anonymize=true;
        }else {
            this.anonymize=false;
            try {
                this.mainzellisteConnection = new MainzellisteConnection(mainzelliste_url, mainzelliste_apikey);
                this.token = new AddPatientToken();
                this.token.addIdType("pid");
                this.httpclient = HttpClients.createDefault();
                createMainzellisteConnection();
            } catch (URISyntaxException | MainzellisteNetworkException | InvalidSessionException e) {
                throw new RuntimeException(e);
            }
        }
    }

    private void createMainzellisteConnection() throws InvalidSessionException, MainzellisteNetworkException {
        this.session = mainzellisteConnection.createSession();
    }

    private HttpPost createHttpPost (String prename, String surname, String birthname, String brithday, String brithmonth, String brithyear) throws UnsupportedEncodingException {
        HttpPost httppost= new HttpPost(mainzelliste_url+"/patients?tokenId="+addPatientToken);
        httppost.addHeader("content-type", "application/x-www-form-urlencoded");
        httppost.addHeader("mainzellisteApiVersion", "3.2");
        List<NameValuePair> idat = new ArrayList<NameValuePair>();
        //idat.add(new BasicNameValuePair("gender", gender));
        idat.add(new BasicNameValuePair("vorname", prename));
        idat.add(new BasicNameValuePair("nachname", surname));
        idat.add(new BasicNameValuePair("geburtsname", birthname));
        idat.add(new BasicNameValuePair("geburtstag", brithday));
        idat.add(new BasicNameValuePair("geburtsmonat", brithmonth));
        idat.add(new BasicNameValuePair("geburtsjahr", brithyear));
        //idat.add(new BasicNameValuePair("plz", ""));
        //idat.add(new BasicNameValuePair("ort", ""));
        idat.add(new BasicNameValuePair("sureness", "true"));
        httppost.setEntity(new UrlEncodedFormEntity(idat, HTTP.UTF_8));
        return httppost;
    }

    private String preprocessIDAT (String name){
        return name.replaceAll("[^a-zA-ZäÄöÖüÜßéÉ]", "");
    }
}
