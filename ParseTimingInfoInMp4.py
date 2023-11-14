import sys
import os
import struct
from optparse import OptionParser

"""
Copyright (c) 2018 Shevach Riabtsev, riabtsev@yahoo.com

Redistribution and use of source is permitted
provided that the above copyright notice and this paragraph are
duplicated in all such forms and that any documentation,
advertising materials, and other materials related to such
distribution and use acknowledge that the software was developed
by the Shevach Riabtsev, riabtsev@yahoo.com. The name of the
Shevach Riabtsev, riabtsev@yahoo.com may not be used to endorse or promote
products derived from this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
"""

def parse_options():
    parser = OptionParser(usage="%prog [-i] [-v]", version="%prog 1.0")

    parser.add_option("-i",
                        dest = "mp4file",
                        help = "mp4-file file",
                        type = "string",
                        action = "store"
                        )
                        
    
    parser.add_option("-v",
                        dest = "verbose",
                        help = "print all intermediate info  (default false)",
                        action="store_true",
                        default=False)
                        
    (options, args) = parser.parse_args()
    

    if options.mp4file:
        return (options.mp4file, options.verbose) 
        
    parser.print_help()
    quit(-1)
    

def FindBox(fp, boxName, start, end, fileSize,verbose):
    """ look for the box (specified by 'boxName') in the range [start, ..., end]
        if the box detected then its size is returned, otherwise 0 is returned
        64-bit sizes are processed too
    """
    if start>=end:  # sanity check
        return 0

    offset=start
    boxSize=0
    # look for the box
    while offset+8 < end:
        fp.seek(offset)
        atomsize= struct.unpack("!I", fp.read(4))[0]
        if atomsize>1 and atomsize<8: # erroneous size
            return 0  # file cut
        
        atomtype=fp.read(4)
        if len(atomtype)<4:
            return 0  # file cut
        if atomsize==0: # box extends to the end of file
            atomsize=fileSize-fp.tell()+4
            if atomtype.decode(encoding = 'UTF-8')==boxName:
                boxSize=atomsize
                break
            return 0 # we have nothing more to look for
        elif atomsize==1: # 64 bit-size
            atomsize= struct.unpack("!Q", fp.read(8))[0]
            
        if atomtype.decode(encoding = 'UTF-8')==boxName:
            boxSize=atomsize
            break
        offset+= atomsize
        if verbose:
            print('%s    size    %12d' %(atomtype.decode(encoding = 'UTF-8'),atomsize))
    
    return boxSize

        
def  Look4VideoTrak(fp, startOffs, endOffs,fileSize,verbose):
    """
     loop over traks until video trak found, False returned in case of error as the first parameter
     otherwise (True, media offset, media size, video track number)
    """
    
    offs=startOffs
    videoTrak=0

    while offs+8 < endOffs:

        trakSize=FindBox(fp,'trak',offs,endOffs,fileSize,verbose)
        if trakSize==0:
            print('Error: trak-atom not found', file=sys.stderr)
            return (False,-1,-1,-1)

        trakOffs=fp.tell()
        mdiaSize=FindBox(fp,'mdia',trakOffs,trakOffs+trakSize-8,fileSize,verbose)
        if mdiaSize==0:
            print('Error: mdia-atom not found', file=sys.stderr)
            return (False,-1,-1,-1)

        mdiaOffs=fp.tell()
        atomSize=FindBox(fp,'hdlr',mdiaOffs,mdiaOffs+mdiaSize-8,fileSize,verbose)
        if atomSize==0:
            print('Error: hdlr-atom not found', file=sys.stderr) 
            return (False,-1,-1,-1)
        
        # skip over version and pre-defined
        fp.seek(8,1)
        trakType=fp.read(4)
        if verbose:
            print('Trak type: ', trakType)
        
        if trakType.decode(encoding = 'UTF-8')=='vide':
            return (True,mdiaOffs,mdiaSize,videoTrak)
        
        fp.seek(trakOffs+trakSize-8,0) # to end of current trak
        videoTrak+= 1
        offs=fp.tell()
    # end while loop
    return (False,-1,-1,-1)

def ProcessCtts(fp,timescale, cttsList): 
    """
        Collect ctts values (presentation times) of each sample in cttsList
        returned number of samples, if ctts table is corrupted returned 0
    """
    fp.seek(4,1) # skip over version
    tableCnt = struct.unpack("!I", fp.read(4))[0]
    numSamples = 0
    for k in range(tableCnt):
        samplesCnt = struct.unpack("!I", fp.read(4))[0]
        sampleDelta = struct.unpack("!I", fp.read(4))[0]
        if samplesCnt==0:
            print('Error: invalid ctts table, sample_cnt=0', file=sys.stderr)
            return 0
        numSamples+=samplesCnt
        sampleDeltaInSec = float(sampleDelta)/timescale
        if samplesCnt==1:
            cttsList.append(sampleDeltaInSec)
        else:
            for _ in range(samplesCnt):
                cttsList.append(sampleDeltaInSec)
    return numSamples
    
def ProcessStts(fp,timescale, sttsList): 
    """
        Collect stts values (decoding times) of each sample in sttsList
        returned number of samples, if stts table is corrupted returned 0
    """
    fp.seek(4,1) # skip over version
    tableCnt = struct.unpack("!I", fp.read(4))[0]
    numSamples = 0
    dts=0
    sttsList.append(0.0)
    
    for k in range(tableCnt):
        samplesCnt = struct.unpack("!I", fp.read(4))[0]
        sampleDelta = struct.unpack("!I", fp.read(4))[0]
        if samplesCnt==0:
            print('Error: invalid stts table, sample_cnt=0', file=sys.stderr)
            return 0
        numSamples+=samplesCnt
            
        if samplesCnt==1:
            dts+=sampleDelta
            sampleDeltaInSec = float(dts)/timescale
            sttsList.append(sampleDeltaInSec)
        else:
            for _ in range(samplesCnt):
                dts+=sampleDelta
                sampleDeltaInSec = float(dts)/timescale
                sttsList.append(sampleDeltaInSec)
    
    sttsList.pop(-1) # the last frame DTs already computed in the previous iteration
    return numSamples
    
if __name__ == "__main__":

    mp4file, verbose = parse_options()
    
    if os.path.isfile(mp4file)==False:
        print('mp4-file [%s] not exist or directory' %mp4file, file=sys.stderr)
        quit(-1)
    
    # get the input file size
    statinfo = os.stat(mp4file)
    fileSize=statinfo.st_size

    inmp4=open(mp4file,'rb')
   
   
    # **************************************************
    # walk through input mp4 tree until video trak found
    # **************************************************

    atomSize=FindBox(inmp4,'moov',0,fileSize,fileSize, verbose)
    if atomSize==0:
        print('Error: moov not found in %s' %mp4file, file=sys.stderr)
        quit(1)

    moovOffs=inmp4.tell()
    moovEnd=moovOffs+atomSize-4

    videoFound,mdiaOffs,mdiaSize,videoTrak=Look4VideoTrak(inmp4, moovOffs, moovEnd,fileSize,verbose)
    if videoFound==False:
        print('Error: No Video Trak Found', file=sys.stderr)
        quit(1)
        
    if verbose:
        print('Video Trak Number %d found' %(videoTrak))
       

    # rewind to start of mdia-atom + atomsize + atomtype 
    inmp4.seek(mdiaOffs,0)
    atomSize=FindBox(inmp4,'mdhd',mdiaOffs,mdiaOffs+mdiaSize-8,fileSize,verbose)
    if atomSize==0:
        print('Error: mdhd-atom not found', file=sys.stderr)
        quit(1)

    # get timescale in input file
    inmp4.seek(12,1) # skip version, creation time, modification time
    timescale= struct.unpack("!I", inmp4.read(4))[0]
    if verbose:
        print('video track timescale is %d' %timescale)

    inmp4.seek(mdiaOffs,0)
    minfSize=FindBox(inmp4,'minf',mdiaOffs,mdiaOffs+mdiaSize-8,fileSize,verbose)
    if minfSize==0:
        print('Error: minf-atom not found', file=sys.stderr)
        quit(0)

    minfOffs=inmp4.tell()
    stblSize=FindBox(inmp4,'stbl',minfOffs,minfOffs+minfSize-8,fileSize,verbose)
    if stblSize==0:
        print('Error: stbl-atom not found in in video track', file=sys.stderr)
        quit(1)
    
    stblOffs=inmp4.tell()
    atomSize=FindBox(inmp4,'stts',stblOffs,stblOffs+stblSize-8,fileSize,verbose)
    if atomSize==0:
        print('Error: stts not found in video track', file=sys.stderr)
        quit(1)
    
    sttsList=[]
    sttsTableNumSamples=ProcessStts(inmp4,timescale, sttsList)
    
    stblOffs=inmp4.tell()
    atomSize=FindBox(inmp4,'ctts',stblOffs,stblOffs+stblSize-8,fileSize,verbose)
    if atomSize==0:
        print("ctts-atom not present, DTS = PTS")
        
        print
        for k,sttsin in enumerate(sttsList,cttsList):
            print('%d    dts = %.4f s,    pts = %.4f s,    diff in ms    0' %(k,stts,stts))
    else:
        cttsList=[]
        numSamples = ProcessCtts(inmp4,timescale,cttsList)
        if sttsTableNumSamples!=numSamples:
            print('Error: number of samples in stts and ctts different', file=sys.stderr)
            quit(1)
            
        print
        for k,(stts,ctts) in enumerate(zip(sttsList,cttsList)):
            print('%d    dts = %.4f s,    pts = %.4f s,    diff in ms    %.2f' %(k,stts,stts+ctts, ctts*1000))
    
    print
    print('number of frames  %d' %sttsTableNumSamples)
        
    
    inmp4.close()
