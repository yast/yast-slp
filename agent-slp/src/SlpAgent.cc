/* SlpAgent.cc
 *
 * An agent for reading the slp configuration file.
 *
 * Authors: Anas Nashif <nashif@suse.de>
 *
 * $Id$
 */

#include <slp.h>
#include "SlpAgent.h"
#include "slp_debug.h"


YCPList Result;
/**
 * Constructor
 */
SlpAgent::SlpAgent() : SCRAgent()
{
}

/**
 * Destructor
 */
SlpAgent::~SlpAgent()
{
}

const YCPList
splitAttrstring (const YCPString &s, const YCPString &c)
{

    if (s.isNull ())
    {
        return YCPNull ();
    }

    if (c.isNull ())
    {
        ycp2error ("Cannot split string using 'nil'");
        return YCPNull ();
    }

    YCPList ret;

    string ss = s->value ();
    string sc = c->value ();

    if (ss.empty () || sc.empty ())
        return ret;

    string::size_type spos = 0;                 // start pos
    string::size_type epos = 0;                 // end pos
    string::size_type ppos = 0;                 // ")" pos

    while (true)
    {
        epos = ss.find_first_of (sc, spos);
        ppos = ss.find_first_of (")", spos);
        if (epos != ppos + 1 && epos != string::npos)
            epos = ss.find_first_of (sc, ppos +1);

        if (epos == string::npos)       // break if not found
        {
            ret->add (YCPString (string (ss, spos)));
            break;
        }

        if (spos == epos)
            ret->add (YCPString (""));
        else
            ret->add (YCPString (string (ss, spos, epos - spos)));      // string piece w/o delimiter

        spos = epos + 1;        // skip c in s

        if (spos == ss.size ()) // c was last char
        {
            ret->add (YCPString (""));  // add "" and break
            break;
        }
    }


    return ret;
}

const YCPList
splitstring (const YCPString &s, const YCPString &c)
{

    if (s.isNull ())
    {
        return YCPNull ();
    }

    if (c.isNull ())
    {
        ycp2error ("Cannot split string using 'nil'");
        return YCPNull ();
    }

    YCPList ret;

    string ss = s->value ();
    string sc = c->value ();

    if (ss.empty () || sc.empty ())
        return ret;

    string::size_type spos = 0;                 // start pos
    string::size_type epos = 0;                 // end pos

    while (true)
    {
        epos = ss.find_first_of (sc, spos);

        if (epos == string::npos)       // break if not found
        {
            ret->add (YCPString (string (ss, spos)));
            break;
        }
        if (spos == epos)
            ret->add (YCPString (""));
        else
            ret->add (YCPString (string (ss, spos, epos - spos)));      // string piece w/o delimiter

        spos = epos + 1;        // skip c in s

        if (spos == ss.size ()) // c was last char
        {
            ret->add (YCPString (""));  // add "" and break
            break;
        }
    }


    return ret;
}




SLPBoolean
MySLPSrvURLCallback (SLPHandle hslp,
             const char *srvurl,
             unsigned short lifetime, SLPError errcode, void *cookie)
{
    YCPMap entry;
    SLPError        err;
    SLPSrvURL       *parsedurl;
    switch(errcode) {
        case SLP_OK:
            err = SLPParseSrvURL(srvurl, &parsedurl);
            check_error_state(err, "Error parsing SrvURL");

            entry->add(YCPString("srvurl"), YCPString(srvurl) );
            entry->add(YCPString("pcSrvType"), YCPString(parsedurl->s_pcSrvType) );
            entry->add(YCPString("pcHost"), YCPString(parsedurl->s_pcHost) );
            entry->add(YCPString("pcPort"), YCPInteger(parsedurl->s_iPort) );
            entry->add(YCPString("pcFamily"), YCPString((const char *)(strlen(parsedurl->s_pcNetFamily)==0)?"IP":"Other"));
            entry->add(YCPString("pcSrvPart"), YCPString(parsedurl->s_pcSrvPart));
            entry->add(YCPString("lifetime"), YCPInteger(lifetime));
            Result->add(entry);
            *(SLPError *) cookie = SLP_OK;
            break;
        case SLP_LAST_CALL:
            break;
        default:
            *(SLPError *) cookie = errcode;
            break;
    } /* End switch. */

    return SLP_TRUE;
}


SLPBoolean
MySLPSrvTypeCallback (SLPHandle hslp,
                      const char *pcSrvTypes,
                      SLPError errcode, void *cookie)
{
    switch(errcode) {
    case SLP_OK:
        Result =  splitstring(YCPString(pcSrvTypes), YCPString(",") );
        *(SLPError *) cookie = SLP_OK;
        break;
    case SLP_LAST_CALL:
        break;
    default:
        *(SLPError *) cookie = errcode;
        break;
    } /* End switch. */

    return SLP_TRUE;
}


SLPBoolean
MyAttrCallback(SLPHandle hslp,
                        const char* attrlist,
                        SLPError errcode,
                        void* cookie )
{

    if(errcode == SLP_OK)
    {
        Result =  splitAttrstring(YCPString(attrlist), YCPString(",") );
    }

    return SLP_TRUE;
}



YCPValue SlpAgentFindAttrs(const char *pcURLOrServiceType, const char *pcScopeList, const char *pcAttrIds)
{
    SLPError    err;
    SLPHandle   hslp;

    err = SLPOpen("en",SLP_FALSE,&hslp);
    check_error_state(err,"Error opening slp handle.");

    err = SLPFindAttrs(hslp,
                       pcURLOrServiceType,
                       pcScopeList,
                       pcAttrIds,
                       MyAttrCallback,
                     0);
    check_error_state(err, "Error registering service with slp.");
    SLPClose(hslp);
    return YCPBoolean(true);
}


YCPValue SlpAgentFindSrvs( const char *pcServiceType)
{
    SLPError err;
    SLPError callbackerr;
    SLPHandle hslp;

    err = SLPOpen ("en", SLP_FALSE, &hslp);
    check_error_state(err,"Error opening slp handle.");

    err = SLPFindSrvs (
            hslp,
            pcServiceType,
            0,      /* use configured scopes */
            0,      /* no attr filter        */
            MySLPSrvURLCallback,
            &callbackerr);
    check_error_state(err, "Error registering service with slp.");

    /* Now that we're done using slp, close the slp handle */
    SLPClose (hslp);

    return YCPBoolean(true);

}

YCPValue SlpAgentFindSrvTypes( const char *pcNamingAuthority)
{
    SLPError err;
    SLPError callbackerr;
    SLPHandle hslp;

    err = SLPOpen ("en", SLP_FALSE, &hslp);
    check_error_state(err,"Error opening slp handle.");

    err = SLPFindSrvTypes (
                           hslp,
                           pcNamingAuthority, /* naming authority */
                           0,       /* use configured scopes */
                           MySLPSrvTypeCallback,
                           &callbackerr);
    check_error_state(err, "Error getting service type with slp.");

        /* Now that we're done using slp, close the slp handle */
    SLPClose (hslp);


    return YCPBoolean(true);

}

/*
 * Get single values from map
 */
const char * getMapValue ( const YCPMap map, const string key)
{

    for (YCPMapIterator i = map->begin(); i != map->end (); i++)
    {
    if (!i.key()->isString())   // key must be a string
    {
        y2error("Invalid key %s, must be a string",
            i.value()->toString().c_str());
    }
    else // everything OK
    {
        string variablename = i.key()->asString()->value();
        if ( variablename == key )
        {
        if (i.value()->isString()) {
            YCPString ret = i.value()->asString();
            return  (const char *)ret->value().c_str();
        }
        }
    }
    }
    return (const char *)"";
}





/**
 * Dir
 */
YCPList SlpAgent::Dir(const YCPPath& path)
{
    y2error("Wrong path '%s' in Read().", path->toString().c_str());
    return YCPNull();
}




void MySLPRegReport(SLPHandle hslp, SLPError errcode, void* cookie)
{
    /* return the error code in the cookie */
    *(SLPError*)cookie = errcode;
}

/**
 * Read
 */
YCPValue SlpAgent::Execute(const YCPPath &path, const YCPValue& value , const YCPValue& opt)
{

    SLPError        err;
    SLPError        callbackerr;
    SLPHandle       hslp;
    const char      *reg_string;
    const char *command = "";


    for (int i=0; i<path->length(); i++)
    {
        if (path->component_str (i)=="reg")
        {
            command = (const char *)path->component_str (i).c_str();
        }
        else if (path->component_str (i)=="dereg")
        {
            command = (const char *)path->component_str (i).c_str();
        }
    }


    if  (!strcmp(command,"reg"))
    {
        reg_string = value->asString()->value().c_str();
        err = SLPOpen("en",SLP_FALSE,&hslp);
        YCPBoolean ret = check_error_state(err, "Error opening slp handle");
        if (!ret->value())
            return YCPBoolean(false);

        /* Register a service with SLP */
        y2milestone("Registering     = %s",reg_string);
        err = SLPReg( hslp,
                reg_string,
                SLP_LIFETIME_MAXIMUM,
                0,
                "(public-key=......my_pgp_key.......)",
                SLP_TRUE,
                MySLPRegReport,
                &callbackerr );
        ret = check_error_state(err, "Error registering service with slp.");
        if (!ret->value())
            return YCPBoolean(false);
        ret = check_error_state(callbackerr, "Error registering service with slp.");
        if (!ret->value())
            return YCPBoolean(false);
    }
    else if (!strcmp(command,"dereg"))
    {
        reg_string = value->asString()->value().c_str();
        err = SLPOpen("en",SLP_FALSE,&hslp);
        YCPBoolean ret = check_error_state(err, "Error opening slp handle");
        if (!ret->value())
            return YCPBoolean(false);

        /* Register a service with SLP */
        y2debug("De-Registering     = %s",reg_string);
        err = SLPDereg( hslp,
                reg_string,
                MySLPRegReport,
                &callbackerr );

        ret = check_error_state(err, "Error Deregistering service with slp.");
        if (!ret->value())
            return YCPBoolean(false);

        y2milestone("Deregistered    = %s",reg_string);

    }

    SLPClose(hslp);
    return YCPBoolean(true);
}

/**
 * Write
 */
YCPBoolean SlpAgent::Write(const YCPPath &path, const YCPValue& value,
    const YCPValue& arg)
{
    y2error("Wrong path '%s' in Write().", path->toString().c_str());
    return YCPBoolean(false);
}

/**
 * Execute
 */
YCPValue SlpAgent::Read(const YCPPath &path, const YCPValue& value, const YCPValue& arg )
{
    YCPList newList;
    if (!Result.isEmpty())
        Result = newList;

    const char *command = "";
    for (int i=0; i<path->length(); i++)
    {
    if (path->component_str (i)=="findsrvs")
    {
        command = (const char *)path->component_str (i).c_str();
    }
    else if (path->component_str (i)=="findattrs")
    {
        command = (const char *)path->component_str (i).c_str();
    }
    else if (path->component_str (i)=="findsrvtypes")
    {
        command = (const char *)path->component_str (i).c_str();
    }
    }
    YCPMap OptionsMap   = value->asMap();

    const char *pcSearchFilter  = getMapValue ( OptionsMap,"pcSearchFilter");
    const char *pcServiceType  = getMapValue ( OptionsMap,"pcServiceType");
    const char *pcURLOrServiceType  = getMapValue ( OptionsMap,"pcURLOrServiceType");
    const char *pcScopeList  = getMapValue ( OptionsMap,"pcScopeList");
    const char *pcAttrIds  = getMapValue ( OptionsMap,"pcAttrIds");
    const char *pcNamingAuthority  = getMapValue ( OptionsMap,"pcNamingAuthority");


    if  (!strcmp(command,"findattrs"))
    {
         YCPValue ret = SlpAgentFindAttrs(pcURLOrServiceType, pcScopeList, pcAttrIds );
         y2debug ("pcURLOrServiceType: %s", pcURLOrServiceType);
    }
    else if (!strcmp(command,"findsrvs"))
    {
         YCPValue ret = SlpAgentFindSrvs(pcServiceType);
         y2debug ("pcServiceType: %s", pcServiceType);
    }
    else if (!strcmp(command,"findsrvtypes"))
    {
         YCPValue ret = SlpAgentFindSrvTypes(pcNamingAuthority);
    }


    return Result;
}

/**
 * otherCommand
 */
YCPValue SlpAgent::otherCommand(const YCPTerm& term)
{
    string sym = term->name();

    if (sym == "SlpAgent") {
        /* Your initialization */
        return YCPVoid();
    }

    return YCPNull();
}
