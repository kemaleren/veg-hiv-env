LoadFunctionLibrary ("HXB2Mapper", {"0": "Universal"});
LoadFunctionLibrary ("lib/dates.bf");
LoadFunctionLibrary ("AncestralMapper");
LoadFunctionLibrary ("LocalMGREV");
LoadFunctionLibrary ("CF3x4");
LoadFunctionLibrary ("NJ");
LoadFunctionLibrary ("TreeTools");
LoadFunctionLibrary ("TreeFunctions");
LoadFunctionLibrary ("dSdNTreeTools");
LoadFunctionLibrary ("DescriptiveStatistics");
LoadFunctionLibrary ("CodonTools");
LoadFunctionLibrary ("lib/tools.bf");
LoadFunctionLibrary ("BranchLengthFitters");

basePath = "../test/";

_nucSequences = "`basePath`input/merged.fas";
_dates        = "`basePath`input/merged.dates";
_regions      = "`basePath`input/merged.prot.parts";
_mrcaTo       = "`basePath`input/mrca.seq";
_ratesTo	  = "`basePath`results/rates_pheno.tsv";
_treesTo	  = "`basePath`results/trees.json";
_ancestralTo  = "`basePath`input/ancestral_sequences.fas";
_sequenceInfo = "`basePath`results/sequences.json";

DataSet allData  = ReadDataFile (_nucSequences);
HarvestFrequencies (positionalFrequencies, allData,3,1,1);
_blStencils = ComputeScalingStencils(0);


nuc3x4 = CF3x4 (positionalFrequencies,GeneticCodeExclusions);
PopulateModelMatrix ("MGLocalQ", nuc3x4);
vectorOfFrequencies = BuildCodonFrequencies(nuc3x4);
Model MGLocal = (MGLocalQ, vectorOfFrequencies,0);

dateInfo     = _loadDateInfo (_dates);
uniqueDates  = _getAvailableDates (dateInfo);

headers = {{"Date", "Segment", "s_diversity", "ns_diversity",  "total_diversity",
                    "ds_diversity", "dn_diversity", 
                    "Length", "PNGS", "IsoelectricPoint",
                    "s_divergence","ns_divergence","total_divergence",
                    "ds_divergence", "dn_divergence"}};

fscanf      (_regions, "Raw", parts);
parts   = Eval (parts);

all_segments = {};
all_segments[0] = {{"gp160", ""}};


for (k = 1; k < Abs (parts); k+=1) {
    all_segments + {{_HXB_env_region_name[k__-1],"" + (3*(parts[k__-1])) + "-" + (3*parts[k__]-1)}};
}

call_count = 0;
GetString          (inputSequenceOrder, allData, -1);

_c2p_mapping = defineCodonToAA ();


rootSeq = None;

treeArrayJSON = {};
seqArrayJSON = {};

for (date_index = 0; date_index < Abs (uniqueDates); date_index += 1) {
    thisDate = uniqueDates["INDEXORDER"][date_index];

	tools.addKeyIfMissing (treeArrayJSON, thisDate, {});
	tools.addKeyIfMissing (seqArrayJSON, thisDate, {});

    for (region = 0; region < Abs (all_segments); region += 1) {
        thisRegion = all_segments [region];
         
    	fprintf (stdout, "[WORKING ON ", thisRegion[0], " FOR `thisDate`]\n");
    	
    	//fprintf (stdout, _selectSequencesByDate (thisDate, dateInfo, inputSequenceOrder), "\n");
    	
        timepoint_info = makePartitionBuiltTreeFitMG ("allData", thisRegion[1], 
            Join (",",_selectSequencesByDate (thisDate, dateInfo, inputSequenceOrder)),
            "sampled`thisDate`", rootSeq, region == 0);
            
        call_count += 1;

		(treeArrayJSON[thisDate])[thisRegion[0]] = timepoint_info["trees"];
	
    	fprintf (_treesTo, CLEAR_FILE, treeArrayJSON);
    
        if (date_index == 0 && region == 0) {
        
        	fprintf (stdout, "[COMPUTING COT SEQUENCE]\n");
            
            UseModel (USE_NO_MODEL);
        
            treeString			= Eval("Format (sampled`thisDate`_tree,1,1)");
            
            Tree				cot_tree_unscaled = treeString;
            cot_data            = ComputeCOT ("cot_tree_unscaled", 0);

            Topology		cot_tree_unscaled = treeString;
                                    
            cot_node_name = "_COT_NODE_";
		    cot_tree_unscaled + {"WHERE": cot_data["Branch"], "PARENT" : cot_node_name, "LENGTH" : cot_data["Split"], "PARENT_LENGTH": cot_data["Split"]};
           
                   
            UseModel (MGLocal);
        
            Tree cot_tree  = cot_tree_unscaled;
            
            ExecuteCommands ("LikelihoodFunction cot_lf = (sampled`thisDate`_filter, cot_tree)");
            
            Optimize           (cot_lf_res, cot_lf);
        
            DataSet			   ds_a = ReconstructAncestors (cot_lf);
            DataSetFilter	   dsf_a = CreateFilter (ds_a,1);
            ACCEPT_ROOTED_TREES = 0;
        
 
            for (sid = 0; sid < dsf_a.species; sid += 1) {
                GetString (seq_name, dsf_a, sid);
                if (seq_name == cot_node_name) {
                    GetDataInfo (rootSeq, dsf_a, sid);
                    break;
                }
            }
            
            assert (sid < dsf_a.species);
            DeleteObject (cot_lf);
            
            fprintf (_ratesTo, CLEAR_FILE, Join ("\t", headers), "\n");
            
            fprintf (_mrcaTo, CLEAR_FILE, ">mrca\n", rootSeq);
            
            
            seqArrayJSON["MRCA"] =  translateCodonToAA (rootSeq, _c2p_mapping, 0);
            
        }
        
        if (region == 0) {
        	seqArrayJSON[thisDate] = timepoint_info["seqs"];
	    	fprintf (_sequenceInfo, CLEAR_FILE, seqArrayJSON);
        }
        
         
        fprintf     (_ratesTo, thisDate, "\t", thisRegion[0], "\t", Join("\t", timepoint_info["div"]), "\t", Join ("\t", timepoint_info["pheno"]), 
            "\t", Join ("\t", divergenceForFilter ("sampled`thisDate`_filter", rootSeq)), "\n");
            
        ExecuteCommands ("DeleteObject (sampled`thisDate`_lf);");
        //date_index = 1000;
        //break;

    }
}

thisDate = "Combined";
tools.addKeyIfMissing (treeArrayJSON, thisDate, {});
tools.addKeyIfMissing (seqArrayJSON, thisDate, {});

fprintf (stdout, "[WORKING ON `thisDate`]\n");
    	
timepoint_info = makePartitionBuiltTreeFitMG ("allData", "", 
	"",
	"everything", rootSeq, 1);

thisRegion = all_segments [0];

(treeArrayJSON[thisDate])[thisRegion[0]] = timepoint_info["trees"];
fprintf (_treesTo, CLEAR_FILE, treeArrayJSON);
seqArrayJSON[thisDate] = (timepoint_info["seqs"])["Ancestral"];
fprintf (_sequenceInfo, CLEAR_FILE, seqArrayJSON);

fprintf (_ancestralTo, CLEAR_FILE, everything_ancestral_filter);


//----------------------------------------------------------------------------------------


function makePartitionBuiltTreeFitMG (dataID, sites, sequences, prefix, rootOn, wantSequences) {
	
    UseModel (USE_NO_MODEL);

	DataSetFilter filteredData = CreateFilter(*dataID,1,sites,sequences);
	Export (fd, filteredData);
	DataSet reduced = ReadFromString (fd);
	
	
	if (rootOn == None) {	
		njTree = InferTreeTopology (1);
	} else {
		DataSet rootSet = ReadFromString (">ROOT_ON_ME\n`rootOn`");
		DataSetFilter choppedRootSeq = CreateFilter (rootSet, 1, sites);
		Export (fd, choppedRootSeq);
		DataSet rootSeq = ReadFromString (fd);
		
		DataSet combined = Combine (rootSeq, reduced);
		DataSetFilter filteredData = CreateFilter (combined, 1);
		
		
		njTree = InferTreeTopology (1);
		
		Topology T = njTree;
		njTree_rr = RerootTree (T, "ROOT_ON_ME");
		Topology T = njTree_rr;

		T - "ROOT_ON_ME";
		njTree = Format (T,0,0);
	}
	
	DataSetFilter filteredData = CreateFilter(*dataID,1,sites,sequences);
	Export (fd, filteredData);
		
	njTree = killZeroBranchesBasedOnNucFit ("reduced", njTree);
	njTree["set_values"][""];
	njTree = njTree["_collapsed_tree"];
	
	UseModel (MGLocal);
    
    ExecuteCommands ("
    	Tree `prefix`_tree = njTree;
    	DataSetFilter `prefix`_filter = CreateFilter(reduced,3,,,GeneticCodeExclusions);
    	USE_LAST_RESULTS = 1;
    	LikelihoodFunction `prefix`_lf = (`prefix`_filter,`prefix`_tree);
    	unconstrainGlobalParameters(\"`prefix`_lf\");
    	Optimize (res, `prefix`_lf);
    	//fprintf (stdout, `prefix`_lf, \"\\n\");
    	if (wantSequences && `prefix`_filter.species > 2) {
    		DataSet `prefix`_ancestors = ReconstructAncestors (`prefix`_lf);
    		DataSetFilter `prefix`_ancestral_filter = CreateFilter(`prefix`_ancestors,3,,,GeneticCodeExclusions);
    	}
    	fixGlobalParameters (\"`prefix`_lf\");
    ");
    
    dSdN = _computeSNSSites ("`prefix`_filter", _Genetic_Code, vectorOfFrequencies, call_count);
    dS = dSdN["Sites"]/dSdN ["SSites"];
    dN = dSdN["Sites"]/dSdN ["NSSites"];
    
    trees = {};
    
    _makePartitionBuiltTreeFitMG_res = {};
    _makePartitionBuiltTreeFitMG_res ["div"] = treeDiv ("`prefix`_tree", dS, dN, trees);
    _makePartitionBuiltTreeFitMG_res ["pheno"] = phenotypeAFilter ("`prefix`_filter");
    _makePartitionBuiltTreeFitMG_res ["trees"] = trees;
       
    if (wantSequences) {
    
    	_makePartitionBuiltTreeFitMG_res ["seqs"] = {"Observed": {},
    			"Ancestral" : {}};
    
    	translateFilterToAA ("`prefix`_filter", (_makePartitionBuiltTreeFitMG_res["seqs"])["Observed"]);
    	if (Eval ("`prefix`_filter.species") > 2) {
    	    translateFilterToAA ("`prefix`_ancestral_filter", (_makePartitionBuiltTreeFitMG_res["seqs"])["Ancestral"]);
    	}
    }
    
    return _makePartitionBuiltTreeFitMG_res;
    
}

//----------------------------------------------------------------------------------------

function translateFilterToAA (filtername, store_here) {
	upto_translateFilterToAA = Eval ("`filtername`.species");
	for (_i_translateFilterToAA = 0; _i_translateFilterToAA < upto_translateFilterToAA; _i_translateFilterToAA+=1) {
				
		GetDataInfo (aa_seq, *filtername, _i_translateFilterToAA);
		GetString   (aa_name, *filtername, _i_translateFilterToAA);
		
		store_here[aa_name] = translateCodonToAA (aa_seq, _c2p_mapping, 0);
		
	}
}

//----------------------------------------------------------------------------------------

function set_values (k,v) {
	if (Type (v) == "Number") {
		Eval ("`k` = " + v);
	}
}

//----------------------------------------------------------------------------------------

function treeDiv (treeiD,dS,dN,store) {
    leafCount = computeMultFactorsWeighted  (treeiD);
    if (Type (store) == "AssociativeList") {
    	store ["Total"] = Eval ("Format (`treeiD`, 1, 1)");
    }
	BRANCH_LENGTH_STENCIL = _blStencils["Syn"];
    if (Type (store) == "AssociativeList") {
    	store ["Synonymous only"] = Eval ("Format (`treeiD`, 1, 1)");
    }
	divInfo 		=	 computeTotalDivergence (treeiD);
	syn  			= 	2*divInfo[0]/leafCount/(leafCount-1);
	BRANCH_LENGTH_STENCIL = _blStencils["NonSyn"];
    if (Type (store) == "AssociativeList") {
    	store ["Nonsynonymous only"] = Eval ("Format (`treeiD`, 1, 1)");
    }
	divInfo 		=	 computeTotalDivergence (treeiD);
	ns  			= 	2*divInfo[0]/leafCount/(leafCount-1);
    BRANCH_LENGTH_STENCIL = 0;
    return {{syn__,ns__,syn__+ns__,syn__*dS__,ns__*dN}};    
}

//----------------------------------------------------------------------------------------

function divergenceForFilter (filterID, rootSeq) {

    total = {{0,0,0,0,0}};
    filter_root = *"filteredData.site_map";
    abridged_rootSeq = ""; abridged_rootSeq * 128;
    for (k = 0; k < Columns(filter_root); k+=1) {
        abridged_rootSeq * rootSeq[filter_root[k]];
    }
    abridged_rootSeq * 0;
    
    copy_count = 0;
    
    for (k = 0; k < *"`filterID`.species"; k+=1) {
        GetDataInfo (seq, *filterID, k);
        GetString (seqName, *filterID, k);
        copyN = get_copy_number (seqName);
        pc = pairwiseCodon (abridged_rootSeq, seq);
        total = total + (pc)*(0+copyN);
        copy_count += copyN;
        
        if (Abs (div_filter_name)) {
            div_filter_name_l = div_filter_name + "_" + seqName + ".lf";
            fprintf (div_filter_name_l, CLEAR_FILE, pairFunction);
        }
    }
    return total*(1/copy_count);
}

//----------------------------------------------------------------------------------------

function pairwiseCodon (seq1, seq2) {
	twoSeqAlignment = ">1\n`seq1`\n>2\n`seq2`";
    DataSet pair = ReadFromString (twoSeqAlignment);
    
    DataSetFilter pairFilter = CreateFilter (pair, 3, "", "", GeneticCodeExclusions);
    Tree pairTree = (1,2);
    LikelihoodFunction pairFunction = (pairFilter, pairTree);
    pairTree.2.synRate :< 10;
    pairTree.2.nonSynRate :< 10;
    Optimize (res, pairFunction);
    dSdN = _computeSNSSites ("pairFilter", _Genetic_Code, vectorOfFrequencies, call_count);
    dS = dSdN["Sites"]/dSdN ["SSites"];
    dN = dSdN["Sites"]/dSdN ["NSSites"];
    return treeDiv ("pairTree",dS,dN, 0);
}

//----------------------------------------------------------------------------------------

lfunction phenotypeASequence (seq) {

    l = Abs (seq^{{"[\\?X\\-]",""}});
    pngs = countPNGS (seq);
    iep = isoElectricPoint (seq);
    
    return {"Length": l, "PNGS": pngs, "Isoelectric Point": iep};
}

//----------------------------------------------------------------------------------------

lfunction get_copy_number (seq_id) {
    if (Type (seq_id) == "String") {
        match = seq_id $ "\_[0-9]+$";
        if (match[0] >= 0) {
            //fprintf (stdout, seq_id, ":", 0 + seq_id[match[0]+1][match[1]], "\n");
            return 0 + seq_id[match[0]+1][match[1]];
        }
    }
    return 1;
}
//----------------------------------------------------------------------------------------

lfunction phenotypeAFilter (filterName) {
    codon_2_aa = defineCodonToAA ();
    
    upper_limit = ^"`filterName`.species";
    all_phenotypes  = {upper_limit, 3};
    counts = {upper_limit,1};
    mean_phenotypes = {1, 3};
    
    
    for (seq_id = 0; seq_id < upper_limit; seq_id += 1) {
        GetDataInfo (this_sequence, ^filterName,seq_id);
        GetString   (this_seq_name, ^filterName,seq_id);
         
        aa_seq = translateCodonToAA(this_sequence,codon_2_aa,0);
        region_pheno             = phenotypeASequence(aa_seq);
        all_phenotypes [seq_id][0] = region_pheno["Length"];
        all_phenotypes [seq_id][1] = region_pheno["PNGS"];
        all_phenotypes [seq_id][2] = region_pheno["Isoelectric Point"];
        counts [seq_id] = get_copy_number (this_seq_name);
    
    }
    
    total = +counts;
    for (k = 0; k < 3; k+=1) {
        mean_phenotypes [k] = (+((all_phenotypes[-1][k])$counts))/total;
    }

    return mean_phenotypes;
}

/*---------------------------------------------------------*/

function computeMultFactorsWeighted (treeID)
{
	treeAVL2  = (^treeID)^ 0;
	leafCount = Max(2,TipCount(^treeID)); 
	
	multFactors = {};
	total_copies = 0;
	
	for (_k=1; _k<Abs(treeAVL2); _k += 1) {
		aNode			= treeAVL2[_k];
		aNodeName		= aNode["Name"];
		parentIndex		= aNode["Parent"];
		_k2				= Abs(aNode["Children"]);
		if (_k2) {
			currentDepth		   = aNode["Below"];
			multFactors[aNodeName] = currentDepth;		
			if (parentIndex > 0)
			{
				(treeAVL2[parentIndex])["Below"] += currentDepth;
			}
		}
		else {
			multFactors[aNodeName]		= get_copy_number (aNodeName);
			total_copies += multFactors[aNodeName];
			(treeAVL2[parentIndex])["Below"] += multFactors[aNodeName];
		}
		
	}

	pKeys 			= Rows(multFactors);
	if (total_copies < 2) {
	    total_copies = 2;
	}
	for (_k=0; _k<Columns(pKeys); _k=_k+1) {
		aNodeName = pKeys[_k];
		multFactors[aNodeName] = multFactors[aNodeName] * (total_copies-multFactors[aNodeName]);
	}
	
	return total_copies;
}
