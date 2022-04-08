package de.samply.adt2fhir;

import de.pseudonymisierung.mainzelliste.client.InvalidSessionException;
import de.pseudonymisierung.mainzelliste.client.MainzellisteConnection;
import de.pseudonymisierung.mainzelliste.client.MainzellisteNetworkException;
import de.pseudonymisierung.mainzelliste.client.Session;
import java.net.URISyntaxException;
import net.sf.saxon.expr.XPathContext;
import net.sf.saxon.lib.ExtensionFunctionCall;
import net.sf.saxon.lib.ExtensionFunctionDefinition;
import net.sf.saxon.om.Sequence;
import net.sf.saxon.om.StructuredQName;
import net.sf.saxon.trans.XPathException;
import net.sf.saxon.value.SequenceType;
import net.sf.saxon.value.StringValue;
import org.apache.commons.codec.digest.DigestUtils;

public class PatientPseudonymizer extends ExtensionFunctionDefinition {


    @Override
    public net.sf.saxon.value.SequenceType[] getArgumentTypes() {
        return new net.sf.saxon.value.SequenceType[] {
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
//                output =  DigestUtils.sha256Hex(gender+prename+surname+birthname+brithdate);//TODO create patientlist call
                // More Information on: https://github.com/medicalinformatics/mainzelliste-client
                try {
                    MainzellisteConnection mainzellisteConnection = new MainzellisteConnection("http://localhost:8080", "youReallyShouldChangeMe");
                    Session session = mainzellisteConnection.createSession();
                    String addPatientToken = session.getAddPatientToken(null, null);
                } catch (MainzellisteNetworkException e) {

                } catch (URISyntaxException e) {

                } catch (InvalidSessionException e) {
                    // create new session here
                }
                return StringValue.makeStringValue(output);
            }

        };
    }
}
