package de.samply.adt2fhir;

import net.sf.saxon.expr.XPathContext;
import net.sf.saxon.lib.ExtensionFunctionCall;
import net.sf.saxon.lib.ExtensionFunctionDefinition;
import net.sf.saxon.om.Sequence;
import net.sf.saxon.om.StructuredQName;
import net.sf.saxon.trans.XPathException;
import net.sf.saxon.value.SequenceType;
import net.sf.saxon.value.StringValue;
import org.apache.commons.codec.digest.DigestUtils;

public class UniqueIdGenerator extends ExtensionFunctionDefinition {


    @Override
    public SequenceType[] getArgumentTypes() {
        return new SequenceType[] {
                SequenceType.SINGLE_STRING,
                SequenceType.SINGLE_STRING,
                SequenceType.SINGLE_STRING, };
    }

    @Override
    public StructuredQName getFunctionQName() {
        return new StructuredQName("hash", "java:de.samply.adt2fhir", "hash");
    }

    @Override
    public SequenceType getResultType(SequenceType[] arg0) {
        return SequenceType.SINGLE_STRING;
    }

    @Override
    public ExtensionFunctionCall makeCallExpression() {
        return new ExtensionFunctionCall() {

            @Override
            public Sequence call(XPathContext ctx, Sequence[] args) throws XPathException {
                String output = "";
                String patient = args[0].iterate().next().getStringValue();
                String diagnosis = args[1].iterate().next().getStringValue();
                String id = args[2].iterate().next().getStringValue();
                output =  DigestUtils.sha256Hex(patient+diagnosis+id);//TODO create patientlist call
                return StringValue.makeStringValue(output);
            }

        };
    }
}
