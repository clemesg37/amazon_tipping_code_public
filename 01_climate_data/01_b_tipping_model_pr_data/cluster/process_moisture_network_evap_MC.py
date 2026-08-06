import numpy as np
import xarray as xr
import pandas as pd
import sys

#load historical network and precip data from the NordESM simulations
hist=xr.open_dataset('data/e_p_moisture_network_amazon_historical.nc')
#gennerate historical average monthly precip
start=1980
end=2015
hist_years=[x for x in range(start,end)]
for y, year in enumerate(hist_years):
    if y==0:
        histpr=hist['monthly_prec_amazon_{}'.format(year)]
    else:
        histpr+=hist['monthly_prec_amazon_{}'.format(year)]
histpr/=len(hist_years)

#Load difference in ET after tipping
deltaET=xr.open_dataset("data/Share_DeltaET_MaxClemens/deltaE_amazon_network.nc")

#specify future scenario and years
ssp=sys.argv[1]
tipscenario=sys.argv[2]
#riskthresh=float(sys.argv[3])
ETresid=True
ETsimul=False
np.random.seed(1)
#nnumber of MC samples
N=100
if ETsimul:
    fut_years=[2030 + 10*x for x in range(7)]
else:
    fut_years=[x for x in range(2030,2100)]

base_pr=[]
moist_flow_sum=[]

for y, year in enumerate(fut_years):

    #load tipping map data
    if ETsimul:
        if 'deforestation' in tipscenario:
            tiprisk=np.loadtxt('data/Share_DeltaET_MaxClemens/with_deforestation/drought_risk_maps/risk_map_1deg_{}_decade{}_rainfact100_mean.txt'.format(ssp,year))
        else:
            tiprisk=np.loadtxt('data/Share_DeltaET_MaxClemens/no_deforestation/drought_risk_maps/risk_map_1deg_{}_decade{}_mean.txt'.format(ssp,year))
    else:
        tiprisk=np.loadtxt('data/Share_DeltaET_MaxClemens/{}/risk_map_1deg_{}_decade{}_mean.txt'.format(tipscenario,ssp,year)) 

    moist_flow_sum.append([])
    #iterating across months
    for m in range(12):
        #Get the original precip and network from the NordESM simulations
        network=xr.open_dataset('data/Share_DeltaET_MaxClemens/original_networks/scenario_{}_decade{}_month{}.nc'.format(ssp,year,f"{m+1:02}"))    
        moistflow=network['network'].values
        precip=network['prec'].values
        evap=network['evap'].values
        #Fraction of evapotranspiration removed by tipping
        evap_frac=np.divide(deltaET.monthly_deltaE_deforestation_amazon.values[m,:],evap)
        evap_frac[evap_frac>1]=1
        evap_frac[evap_frac<0]=0
        evap_frac[np.isnan(evap_frac)]=1
        #append for storage the baseline precipitation
        if m==0:
            prm=np.expand_dims(precip,0)
        else:
            prm=np.append(prm,np.expand_dims(precip,0),axis=0)

        #run MC samples
        for n in range(N):
            #set the sources which have not tipped to zero, before summing over tipped sources and subtracting from the precipitation data 
            #get those grid-cells that haven't tipped, based on whether uniform 0-1 sample exceeds the tipping risk
            not_tipped=np.random.uniform(size=np.shape(tiprisk))>tiprisk
            #Set moisture flows of cells that didn't tip to 0, then subtract moisture flows from the precip data
            moistflow_alt=np.copy(moistflow)
            moistflow_alt[:,not_tipped]=0
            #Only remove the moisture flows which are not left behind, based on evap frac
            if ETresid or ETsimul:
                moistflow_alt=moistflow_alt*evap_frac

            precip_alt=precip-np.nansum(moistflow_alt,axis=1)
            #save altered preciptiation 
            if n==0:
                prm_alt=np.expand_dims(precip_alt,0)
            else:
                prm_alt=np.append(prm_alt,np.expand_dims(precip_alt,0),axis=0) 
        if m==0:
            prmm_alt=np.expand_dims(prm_alt,0)
        else:
            prmm_alt=np.append(prmm_alt,np.expand_dims(prm_alt,0),axis=0)

        moist_flow_sum[y].append(moistflow.sum(axis=1))
    base_pr.append(prm) 

    prmm_alt=np.swapaxes(prmm_alt,0,1)
    PC_CC=100*(prm-histpr)/histpr
    PC_CCTIP=100*(prmm_alt-np.array(histpr))/np.array(histpr)

    if y==0:
        output=np.expand_dims(PC_CC,0)
        output_tip=np.expand_dims(PC_CCTIP,0)
    else:
        output=np.append(output,np.expand_dims(PC_CC,0),axis=0)
        output_tip=np.append(output_tip,np.expand_dims(PC_CCTIP,0),axis=0)

    print('done ' + str(year))
    print(np.mean(evap_frac))

base_pr=np.array(base_pr)
moist_flow_sum=np.array(moist_flow_sum)

print('% of instances with sum of moisture flows > precip: ' + str(100*len(np.where(base_pr<moist_flow_sum)[0])/(416*70*12)))
print('% of instannces where the baseline precip is also > 1mm: ' + str(100*len(np.where((base_pr<moist_flow_sum)&(base_pr>1))[0])/(416*70*12)))

#prepare output
ds=xr.Dataset(data_vars=dict(histpr=(["month","coord"],histpr.values),PC_CC=(["year",'month','coord'],output),PC_CCTIP=(['year','sample','month','coord'],output_tip),)
        ,coords=dict(lon=("lon",network['lon'].values),lat=("lat",network['lat'].values),year=('year',fut_years),month=('month',[x for x in range(12)]),))

#output
if ETresid:
    if ETsimul:
        ds.to_netcdf('data/PRECIP_CHANGES/amazon_precip_ETresid_ETsimul_perc_changes_ssp_{}_tipscenario_{}_MC.nc'.format(ssp,tipscenario))
    else:
        ds.to_netcdf('data/PRECIP_CHANGES/amazon_precip_ETresid_perc_changes_ssp_{}_tipscenario_{}_MC.nc'.format(ssp,tipscenario))
else:
    ds.to_netcdf('data/PRECIP_CHANGES/amazon_precip_perc_changes_ssp_{}_tipscenario_{}_MC.nc'.format(ssp,tipscenario))
    

