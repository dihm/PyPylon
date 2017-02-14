#ifndef HACK_H
#define HACK_H

#define ACCESS_CGrabResultPtr_GrabSucceeded(x)  x->GrabSucceeded()
#define ACCESS_CGrabResultPtr_GetErrorDescription(x)  x->GetErrorDescription()
#define ACCESS_CGrabResultPtr_GetErrorCode(x)  x->GetErrorCode()
#define ACCESS_CGrabResultPtr_GetPayloadType(x)  x->GetPayloadType()
#define ACCESS_CGrabResultPtr_GetChunkDataNodeMap(x)  x->GetChunkDataNodeMap()

#endif