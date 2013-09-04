/* SlpAgent.h
 *
 * Slp agent implementation
 *
 * Authors: Anas Nashif <nashif@suse.de>
 *
 * $Id$
 */

#ifndef _SlpAgent_h
#define _SlpAgent_h

#include <Y2.h>
#include <scr/SCRAgent.h>

/**
 * @short An interface class between YaST2 and Slp Agent
 */
class SlpAgent : public SCRAgent
{
private:
    /**
     * Agent private variables
     */

public:
    /**
     * Default constructor.
     */
    SlpAgent();

    /**
     * Destructor.
     */
    virtual ~SlpAgent();

    /**
     * Provides SCR Read ().
     * @param path Path that should be read.
     * @param arg Additional parameter.
     */
    virtual YCPValue Read(const YCPPath &path,
			  const YCPValue& arg = YCPNull (),
                          const YCPValue& opt = YCPNull());

    /**
     * Provides SCR Write ().
     */
    virtual YCPBoolean Write(const YCPPath &path,
			   const YCPValue& value,
			   const YCPValue& arg = YCPNull());

    /**
     * Provides SCR Execute ().
     */
    virtual YCPValue Execute(const YCPPath &path,
			     const YCPValue& value,
			     const YCPValue& arg );

    /**
     * Provides SCR Dir ().
     */
    virtual YCPList Dir(const YCPPath& path);

    /**
     * Used for mounting the agent.
     */
    virtual YCPValue otherCommand(const YCPTerm& term);
};

#endif /* _SlpAgent_h */
