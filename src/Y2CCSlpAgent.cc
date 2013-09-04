/* Y2CCSlpAgent.cc
 *
 * Slp agent implementation
 *
 * Authors: Anas Nashif <nashif@suse.de>
 *
 * $Id$
 */

#include <scr/Y2AgentComponent.h>
#include <scr/Y2CCAgentComponent.h>

#include "SlpAgent.h"

typedef Y2AgentComp <SlpAgent> Y2SlpAgentComp;

Y2CCAgentComp <Y2SlpAgentComp> g_y2ccag_slp ("ag_slp");
