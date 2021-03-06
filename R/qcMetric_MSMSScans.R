
#####################################################################

#'
#' Metric for msmsscans.txt, showing TopN over RT.
#'
#' @importFrom data.table as.data.table setkey
#'
qcMetric_MSMSScans_TopNoverRT =  setRefClass(
  "qcMetric_MSMSScans_TopNoverRT",
  contains = "qcMetric",
  methods = list(initialize=function() {  callSuper(
    helpTextTemplate = 
      "TopN over retention time. Similar to ID over RT, this metric reflects the complexity of the sample
at any point in time. Ideally complexity should be made roughly equal (constant) by choosing a proper (non-linear) LC gradient.
See [http://www.ncbi.nlm.nih.gov/pubmed/24700534](Moruz et al., GradientOptimizer: An open-source graphical environment for calculating optimized gradients in reversed-phase
liquid chromatography, Proteomics, 06/2014; 14) for details.
    
Heatmap score [MS<sup>2</sup> Scans: TopN over RT]: Rewards uniform (function Uniform) TopN events over time.
",
    workerFcn = function(.self, df_msmsScans)
    {
      ## completeness check
      stopifnot(.self$checkInput(c("fc.raw.file", "retention.time", "scan.event.number", "rRT"), colnames(df_msmsScans)))
      
      dd = as.data.table(df_msmsScans[, c("fc.raw.file", "retention.time", "scan.event.number", "rRT")])
      setkey(dd, fc.raw.file, retention.time) ## sort by RT
      ## find the highest scan event (SE) after an MS1 scan
      DF_max = dd[, {
          idx = which(getMaxima(scan.event.number, thresh_rel = 0.0))
          maxSE = scan.event.number[idx]
          RTbin = rRT[idx]
          list(maxSE = maxSE, rRT = RTbin)
        }, by = "fc.raw.file"]
      
      DFmse = DF_max[, list(topN = as.double(median(maxSE))),
                      by = c("fc.raw.file", "rRT")]
      head(DFmse)
      
      lpl =
        byXflex(DFmse, DFmse$fc.raw.file, 6, plot_TopNoverRT, sort_indices = FALSE)
      
      ## QC measure for smoothness of TopN over RT
      qc_TopNRT = ddply(DFmse, "fc.raw.file", function(x) data.frame(val = qualUniform(x$topN)))
      colnames(qc_TopNRT)[colnames(qc_TopNRT) == "val"] = .self$qcName
      
      return(list(plots = lpl, qcScores = qc_TopNRT))
    }, 
    qcCat = "LC", 
    qcName = "MS^2*Scans:~TopN~over~RT", 
    orderNr = 0120
  )
    return(.self)
  })
)

#####################################################################

qcMetric_MSMSScans_MSMSIntensity =  setRefClass(
  "qcMetric_MSMSScans_MSMSIntensity",
  contains = "qcMetric",
  methods = list(initialize=function() {  callSuper(
    helpTextTemplate = 
      "MS/MS identifications can be 'bad' for a couple of reasons. It could be computational, i.e. ID rates
are low because you specified the wrong protein database or modifications (not our concern here).
Another reason is low/missing signals for fragment ions,
e.g. due to bad (quadrupole/optics) ion transmission (charging effects), too small isolation windows, etc.

Hence, we plot the TIC and base peak intensity of all MS/MS scans (incl. unidentified ones) per Raw file.
Depending on the setup, these intensities can vary, but telling apart good from bad samples
should never be a problem. If you only have bad samples, you need to know the intensity a good sample would reach.

To automatically score this, we found that the TIC should be 10-100x larger than the base peak, i.e. there 
should be many other ions which are roughly as high (a good fragmentation ladder).
If there are only a few spurious peaks (bad MS/MS), the TIC is much lower. Thus, we score the ratio 
BP * 10 > TIC (this would be 100% score). If it's only BP * 3 < TIC, we say this MS/MS failed (0%).
Anything between 3x and 10x gets a score in between. The score for the Raw file is computed as the
median score across all its MS/MS scans.

Heatmap score [MS<sup>2</sup> Scans: Intensity]: Linear score (0-100%) between 3 < (TIC / BP) < 10. 
    ",
    workerFcn = function(.self, d_msmsScan, score_min_factor = 3, score_max_factor = 10)
    {
      ## completeness check
      stopifnot(.self$checkInput(c("fc.raw.file", "total.ion.current", "base.peak.intensity"), colnames(d_msmsScan)))
      
      ## use data.table for aggregation, its MUCH faster than ddply() and uses almost no extra memory
      dd = as.data.table(d_msmsScan[, c("fc.raw.file", "total.ion.current", "base.peak.intensity")])
      dd$log.total.ion.current = log10(dd$total.ion.current)
      dd$log.base.peak.intensity = log10(dd$base.peak.intensity)
      log.dd.tic = dd[,list(mean=mean(log.total.ion.current),
                        min=min(log.total.ion.current),
                        lower=quantile(log.total.ion.current, .25, na.rm=TRUE),
                        middle=quantile(log.total.ion.current, .50, na.rm=TRUE),
                        upper=quantile(log.total.ion.current, .75, na.rm=TRUE),
                        max=max(log.total.ion.current)),
                    by='fc.raw.file']
      log.dd.bpi = dd[,list(mean2=mean(log.base.peak.intensity),
                        min2=min(log.base.peak.intensity),
                        lower2=quantile(log.base.peak.intensity, .25, na.rm=TRUE),
                        middle2=quantile(log.base.peak.intensity, .50, na.rm=TRUE),
                        upper2=quantile(log.base.peak.intensity, .75, na.rm=TRUE),
                        max2=max(log.base.peak.intensity)),
                  by='fc.raw.file']
      ## merge, so we have one table for byXflex()
      dd.all = merge(log.dd.tic, log.dd.bpi, by='fc.raw.file')
      
      ## for scoring...
      dd.ratio = dd[,list(ratio=median(total.ion.current/base.peak.intensity)), by ='fc.raw.file']
      dd.ratio
      
      
      plot_MSMSintensity = function(dd.all) {
        pl = ggplot(data = dd.all, aes(x = fc.raw.file)) + 
                geom_boxplot(stat = "identity", aes(col = "TIC", ymin = min, lower = lower, middle = middle, upper = upper, ymax = max)) +
                geom_boxplot(stat = "identity", aes(col = "Base\nPeak", ymin = min2, lower = lower2, middle = middle2, upper = upper2, ymax = max2, width = 0.3)) +
                scale_color_manual("MS/MS\nintensity", values = c("TIC" = "black", "Base\nPeak" = "blue")) +
                ylim(0, NA) +
                scale_x_discrete_reverse(dd.all$fc.raw.file) +
                ggtitle("[experimental] MSMSscans: MS/MS intensity") +
                xlab("") +
                ylab(expression('intensity (' * log[10] * ')')) +
                coord_flip()
      }
      
      lpl = byXflex(dd.all, dd.all$fc.raw.file, 12, plot_MSMSintensity, sort_indices = FALSE)
      
      
      ## QC measure for intensity ratio below expected threshold (3x-10x by default)
      qc_MSMSint = ddply(dd.ratio, "fc.raw.file", 
                     function(x) data.frame(val = qualLinThresh(x$ratio - score_min_factor, t = score_max_factor - score_min_factor)))
      colnames(qc_MSMSint)[colnames(qc_MSMSint) == "val"] = .self$qcName
      
      return(list(plots = lpl, qcScores = qc_MSMSint))
    }, 
    qcCat = "MS", 
    qcName = "MS^2*Scans:~Intensity", 
    orderNr = 0245
  )
    return(.self)
  })
)

#####################################################################

qcMetric_MSMSScans_IonInjTime =  setRefClass(
  "qcMetric_MSMSScans_IonInjTime",
  contains = "qcMetric",
  methods = list(initialize=function() {  callSuper(
    helpTextTemplate = 
      "Ion injection time score - should be as low as possible to allow fast cycles. Correlated with peptide intensity.
Note that this threshold needs customization depending on the instrument used (e.g., ITMS vs. FTMS).

Heatmap score [MS<sup>2</sup> Scans: Ion Inj Time]: Linear score as fraction of MS/MS below the threshold. 
",
    workerFcn = function(.self, df_msmsScans, threshold_iit)
    {
      ## completeness check
      stopifnot(.self$checkInput(c("fc.raw.file", "ion.injection.time", "rRT"), colnames(df_msmsScans)))
      
      ## use data.table for aggregation, its MUCH faster than ddply() and uses almost no extra memory
      dd = as.data.table(df_msmsScans[, c("fc.raw.file", "ion.injection.time", "rRT")])

      ## average injection time over RT
      DFmIIT = dd[, list(medIIT = median(ion.injection.time)), by=c("fc.raw.file", "rRT")]

      ## average injection time overall
      DFmIITglob = dd[, list(mean = mean(ion.injection.time)), by = "fc.raw.file"]

      lpl =
        byXflex(DFmIIT, DFmIIT$fc.raw.file, 6, plot_IonInjectionTimeOverRT, sort_indices = FALSE,
                stats = DFmIITglob,
                extra_limit = threshold_iit)
      
      
      ## QC measure for injection times below expected threshold
      DFmIIT_belowThresh = dd[,
                              list(belowThresh_IIT = sum(ion.injection.time < threshold_iit, na.rm = TRUE) / .N),
                              by = "fc.raw.file"]
      
      qc_IIT = ddply(DFmIIT_belowThresh, "fc.raw.file", 
                     function(x) data.frame(val = qualLinThresh(x$belowThresh_IIT, t = 1)))
      colnames(qc_IIT)[colnames(qc_IIT) == "val"] = .self$qcName
      
      return(list(plots = lpl, qcScores = qc_IIT))
    }, 
    qcCat = "MS", 
    qcName = "MS^2*Scans:~Ion~Inj~Time", 
    orderNr = 0240
  )
    return(.self)
  })
)

#####################################################################

qcMetric_MSMSScans_TopN =  setRefClass(
  "qcMetric_MSMSScans_TopN",
  contains = "qcMetric",
  methods = list(initialize=function() {  callSuper(
    helpTextTemplate = 
      "Reaching TopN on a regular basis indicates that all sections of the LC gradient
deliver a sufficient number of peptides to keep the instrument busy. This metric somewhat summarizes 'TopN over RT'.

Heatmap score [MS<sup>2</sup> Scans: TopN high]: rewards if TopN was reached on a regular basis (function qualHighest)
",
    workerFcn = function(.self, df_msmsScans)
    {
      ## completeness check
      stopifnot(.self$checkInput(c("fc.raw.file", "scan.event.number"), colnames(df_msmsScans)))
      
      ## check if scan.event.number requires fixing
      ## (e.g. when MS3 events are recorded between MS2 events, there are gaps in the numbering)
      ## we close the gaps by requiring consecutive scan event numbers in MS2
      scan.events = df_msmsScans[, c("scan.event.number", "fc.raw.file")]
      while (TRUE) { ## should be at most max(scan.even.number) iterations
        se_pos = 1 + which(diff(scan.events$scan.event.number) > 1) ## position of gaps>1
        if (length(se_pos) == 0) break;
        scan.events$scan.event.number[se_pos] = scan.events$scan.event.number[se_pos] - 1
      }

      ## use data.table for aggregation, its MUCH faster than ddply() and uses almost no extra memory
      DFc = as.data.table(scan.events)[, list(n=.N), by=c("scan.event.number", "fc.raw.file")]

      dfc.ratio = ddply(DFc, "fc.raw.file", function(x, maxn)
      {
        ## sort x by scan event
        event_count = x$n
        ## verify its monotonically increasing
        if (is.unsorted(rev(event_count))) {
          #print(x)
          stop("Scan event distribution is not monotonically increasing!")
        } 
        ## verify that there are no gaps
        if (max(x$scan.event.number) != nrow(x)) {
          #print(x)
          stop("Scan event distribution has unexpected holes...!")
        }
        
        event_pre = c(event_count[-1], 0)
        event_diff = event_count - event_pre
        
        ## build new DF of fixed length
        sn = x$scan.event.number
        if (max(sn) < maxn) 
        {
          event_diff = c(event_diff, rep(0, maxn-max(sn)))
          sn = c(sn, (max(sn)+1):maxn)
        }
        DF.new = data.frame(scan.event.number = sn, n = event_diff)
        return (DF.new)
      }, maxn = max(DFc$scan.event.number))
      head(dfc.ratio)
      
      lpl =
        byXflex(dfc.ratio, dfc.ratio$fc.raw.file, 9, plot_TopN, sort_indices = FALSE)
      
      ## QC measure for always reaching the maximum TopN
      maxTopN = max(dfc.ratio$scan.event.number)
      qc_TopN = ddply(dfc.ratio, "fc.raw.file", function(x) data.frame(val = qualHighest(x$n, maxTopN)))
      colnames(qc_TopN)[colnames(qc_TopN) == "val"] = .self$qcName
      
      return(list(plots = lpl, qcScores = qc_TopN))
    }, 
    qcCat = "MS", 
    qcName = "MS^2*Scans:~TopN~high", 
    orderNr = 0350
  )
    return(.self)
  })
)

#####################################################################

qcMetric_MSMSScans_TopNID =  setRefClass(
  "qcMetric_MSMSScans_TopNID",
  contains = "qcMetric",
  methods = list(initialize=function() {  callSuper(
    helpTextTemplate = 
      "Looking at the 
identification rates per scan event (i.e. the MS/MS scans after a survey scan) can give 
hints on how well scheduled precursor peaks could be fragmented and identified.
If performance drops for the later MS/MS scans, then the LC peaks are probably not wide enough to deliver
enough eluent or the intensity threshold to trigger the MS/MS event should be lowered (if LC peak is already over),
or increased (if LC peak is still to weak to collect enough ions).

Heatmap score [MS<sup>2</sup> Scans: TopN ID over N]: Rewards uniform identification performance across all scan events.
",
    workerFcn = function(.self, df_msmsScans)
    {
      ## completeness check
      stopifnot(.self$checkInput(c("fc.raw.file", "scan.event.number", "identified"), colnames(df_msmsScans)))
      
      ## use data.table for aggregation, its MUCH faster than ddply() and uses almost no extra memory
      DF = as.data.table(df_msmsScans[, c("fc.raw.file", "scan.event.number", "identified")])[, list(n=.N), by=c("fc.raw.file", "scan.event.number", "identified")]
      
      # try KS on underlying data instead of using qualUniform()
      #   DF2= ddply(df_msmsScans, "fc.raw.file", function(rf){
      #     cat(class(rf))
      #     cat(rf$fc.raw.file[1])
      #     idx_p = rf$identified=="+"
      #     cat(length(idx_p) %+% "\n")
      #     kk = ks.test(rf$scan.event.number[idx_p], rf$scan.event.number[-idx_p])
      #     cat(kk$p.value)
      #     kk$statistic  # = 'D' ,,  p.value is much smaller (~0)
      #   })
      #   --> fail, 'D' and p-values are too low
      df.ratio = ddply(DF, c("scan.event.number", "fc.raw.file"), function(x)
      {
        xp = xm = 0
        if ("+" %in% x$identified) xp = x$n[x$identified=="+"]
        if ("-" %in% x$identified) xm = x$n[x$identified=="-"]
        ratio = xp * 100 / sum(xp, xm)
        return (data.frame(ratio = ratio, count = sum(x$n)))
      })
      head(df.ratio)
      
      lpl = byXflex(df.ratio, df.ratio$fc.raw.file, 9, plot_ScanIDRate, sort_indices = FALSE)
      
      ## QC measure for constantly identifiying peptides, irrespective of scan event number
      ## -- we weight scan events by their number of occurence
      qc_TopN_ID = ddply(df.ratio, "fc.raw.file", function(x) data.frame(val = qualUniform(x$ratio, x$count)))
      colnames(qc_TopN_ID)[colnames(qc_TopN_ID) == "val"] = .self$qcName
      
      return(list(plots = lpl, qcScores = qc_TopN_ID))
    }, 
    qcCat = "MS", 
    qcName = "MS^2*Scans:~TopN~ID~over~N", 
    orderNr = 0380
  )
    return(.self)
  })
)

