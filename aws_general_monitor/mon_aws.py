#!/usr/bin/env  python
import boto3
import sys
from datetime import datetime

client = boto3.client('ec2','sa-east-1')

today = datetime.strptime(datetime.now().strftime('%Y-%m-%d'), "%Y-%m-%d")


def regionsList():
	list=[]
	for region in client.describe_regions()['Regions']:
		list.append(region['RegionName'])
	return list


def discoverRegions():
	end_line=""
	print '{ "data":  [ '
	for region in regionsList():
		print end_line
		print '{ "{#REGION}": "'+region+'" }'
		end_line=","
	print '] }'


def discoverReservedInstances():
	end_line=""
	print '{ "data":  [ '
	for region in client.describe_regions()['Regions']:
		#print region['RegionName']
		client2 = boto3.client('ec2',region['RegionName'])
		for instance in client2.describe_reserved_instances(Filters=[{'Name':'state','Values':['active']}])['ReservedInstances']:
			print end_line
			print '{ "{#REGION}": "'+region['RegionName']+'", "{#TYPE}": "'+instance['InstanceType']+'", "{#RESERVID}": "'+instance['ReservedInstancesId']+'" }'
			end_line=","
	print '] }'


def reservedInstanceExpirate(region,id):
	client = boto3.client('ec2',region)
	today = datetime.strptime(datetime.now().strftime('%Y-%m-%d'), "%Y-%m-%d")
	#reserved-instances-id
	instance=client.describe_reserved_instances(Filters=[{'Name':'reserved-instances-id','Values':[id]}])['ReservedInstances'][0]
	#print instance
	date_expire = datetime.strptime(instance['End'].strftime('%Y-%m-%d'), "%Y-%m-%d")
	#print date_expire
	days2expire = abs((date_expire - today).days)
	print days2expire


def discoverSgsInUse():
	groups={}
	for region in regionsList():
		groups[region]={}
		client2 = boto3.client('ec2',region)
		for instances in client2.describe_instances(Filters=[{'Name':'instance-state-name','Values':['running']}])['Reservations']:
			for instance in instances["Instances"]:
				for sg in instance["SecurityGroups"]:
					#print sg
					if sg["GroupId"] not in groups[region]:
						groups[region][sg["GroupId"]]=sg["GroupName"]
	#print groups
	end_line=""
	print '{ "data":  [ '
	for g_region in groups:
		#print g_region
		for g_sg in groups[g_region]:
			print end_line
			print '{ "{#REGION}": "'+g_region+'", "{#SG_ID}" : "'+g_sg+'", "{#SG_NAME}" : "'+groups[g_region][g_sg]+'"}'
			end_line=","
	print '] }'


def sgPortsToUniverse(region,sg):
	client = boto3.client('ec2',region)
	sgInfo=client.describe_security_groups(Filters=[{'Name':'group-id','Values':[sg]}])
	for rule in sgInfo["SecurityGroups"][0]["IpPermissions"]:
		for ipRange in rule["IpRanges"]:
			if "0.0.0.0/0" in ipRange["CidrIp"]:
				print ipRange["CidrIp"] + "," + str(rule["FromPort"]) + "," + str(rule["ToPort"]) + "," + rule["IpProtocol"] + ";"
		for ipV6Range in rule["Ipv6Ranges"]:
			if "::/0" in ipV6Range["CidrIpv6"]:
				print ipV6Range["CidrIpv6"] + "," + str(rule["FromPort"]) + "," + str(rule["ToPort"]) + "," + rule["IpProtocol"]  + ";"
		#print rule


def countAvailableVolumes(region):
	client = boto3.client('ec2',region)
	print len(client.describe_volumes(Filters=[{'Name':'status','Values':['available']}])["Volumes"])


def helpMe():
	print "Opcoes:"
	print "discoverSgsInUse - Discover de security Groups"
	print "discoverReservedInstances - Discover de Instancias reservadas"
	print "discoverRegions - Discover de Regioes"


if len(sys.argv) > 1:
	arg1=sys.argv[1]
	if arg1 == "discoverReservedInstances":
		discoverReservedInstances()
	elif arg1 == "discoverSgsInUse":
		discoverSgsInUse()
	elif arg1 == "sgPortsToUniverse"  and len(sys.argv) > 3:
		sgPortsToUniverse(sys.argv[2],sys.argv[3])
	elif arg1 == "regionsList":
		print regionsList()
	elif arg1 == "discoverRegions":
		discoverRegions()
	elif arg1 == "countAvailableVolumes" and len(sys.argv) > 2:
		countAvailableVolumes(sys.argv[2])
	elif sys.argv[1] == "reservedExpirate" and len(sys.argv) > 3:
		reservedInstanceExpirate(sys.argv[2],sys.argv[3])
	else:
		helpMe()
else:
 	helpMe()
