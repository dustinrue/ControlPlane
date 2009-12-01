-- phpMyAdmin SQL Dump
-- version 3.1.4deb1
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Jul 17, 2009 at 10:20 AM
-- Server version: 5.0.67
-- PHP Version: 5.2.6-3

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: `crashlogs_main`
--

-- --------------------------------------------------------

--
-- Table structure for table `apps`
--

-- contains a list of all applications that are accepted
-- bundleidentifier: the bundle identifier of the application allowed to provide crash reports
-- symbolicate: if the todo table should be filled to remotely symbolicate crash reports for this applciation
CREATE TABLE IF NOT EXISTS `apps` (
  `id` bigint(20) unsigned NOT NULL auto_increment,
  `bundleidentifier` varchar(250) NOT NULL,
  `name` varchar(50) NOT NULL,
  `symbolicate` tinyint(4) default '0',
  `issuetrackerurl` text default NULL,
  `notifyemail` text default NULL,
  `notifypush` text default NULL,
  PRIMARY KEY  (`id`),
  KEY `symbolicate` (`symbolicate`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `crash`
--

-- contains all crash log data
-- userid: if there was some kind of user/device identification provided in the crash log, this contains the string provided
-- contact: if there was some kind of contact information provided, this contains the string
-- systemversion: the version of the operation system running when this crash was sent (!!), could be different to the version the crash happened
-- bundleidentifier: the bundle identifier of the application this crash report is associated with
-- serverversion: the version of the app that sent this report
-- version: the version of the app that crashed
-- description: if there was some description text provided, this contains the string
-- log: the actual crash log data
-- timestamp: the timestamp the crash log data was added to the database
-- groupid: the crash group this crash was associated with
CREATE TABLE IF NOT EXISTS `crash` (
  `id` bigint(20) unsigned NOT NULL auto_increment,
  `userid` varchar(255) collate utf8_unicode_ci default NULL,
  `contact` varchar(255) collate utf8_unicode_ci default NULL,
  `systemversion` varchar(25) collate utf8_unicode_ci default NULL,
  `bundleidentifier` varchar(250) collate utf8_unicode_ci default NULL,
  `applicationname` varchar(50) collate utf8_unicode_ci default NULL,
  `senderversion` varchar(15) collate utf8_unicode_ci NOT NULL default '',
  `version` varchar(15) collate utf8_unicode_ci default NULL,
  `description` mediumtext collate utf8_unicode_ci,
  `log` text collate utf8_unicode_ci NOT NULL,
  `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP,
  `groupid` bigint(20) unsigned default '0',
  PRIMARY KEY  (`id`),
  KEY `timestamp` (`timestamp`),
  KEY `applicationname` (`applicationname`),
  KEY `userid` (`userid`),
  KEY `version` (`version`),
  KEY `senderversion` (`senderversion`),
  KEY `contact` (`contact`),
  KEY `systemversion` (`systemversion`),
  KEY `bundleidentifier` (`bundleidentifier`),
  FULLTEXT KEY `log` (`log`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `crash_groups`
--

-- contains a list of groups for similar crashes
-- bundleidentifier: the bundle identifier that this crash group is associated with
-- affected: the version of the application that has this crash
-- fix: the version which will fix this crash
-- pattern: the string to search for to detect if a crash belongs to this group
-- description: an optional description text which can be added in the admin UI
-- amoun: the amount crash logs associated with this crash group
CREATE TABLE IF NOT EXISTS `crash_groups` (
  `id` bigint(20) unsigned NOT NULL auto_increment,
  `bundleidentifier` varchar(250) collate utf8_unicode_ci default NULL,
  `affected` varchar(20) collate utf8_unicode_ci default NULL,
  `fix` varchar(20) collate utf8_unicode_ci default NULL,
  `pattern` varchar(250) collate utf8_unicode_ci NOT NULL default '',
  `description` text collate utf8_unicode_ci,
  `amount` bigint(20) default '0',
  PRIMARY KEY  (`id`),
  KEY `affected` (`affected`,`fix`),
  KEY `applicationname` (`bundleidentifier`),
  KEY `pattern` (`pattern`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `symbolicated`
--

-- contains a todo list for crashes that need to be symbolicated by a remote task
-- crashid: the id of the crash log data to symbolicate
-- done: value of 1 if symbolification is completed, 0 if to be done
CREATE TABLE IF NOT EXISTS `symbolicated` (
  `id` bigint(20) unsigned NOT NULL auto_increment,
  `crashid` bigint(20) unsigned NOT NULL default '0',
  `done` int(11) NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `crashid` (`crashid`),
  KEY `done` (`done`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `versions`
--

-- contains a list of versions for a specific application
-- bundleidentifier: the application this versions belongs to
-- version: the version number as a string
-- status: the status of this version, see config.php for values
CREATE TABLE IF NOT EXISTS `versions` (
  `id` bigint(20) unsigned NOT NULL auto_increment,
  `bundleidentifier` varchar(250) collate utf8_unicode_ci default NULL,
  `version` varchar(20) collate utf8_unicode_ci default NULL,
  `status` int(11) NOT NULL default '0',
  `notify` int(11) NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `version` (`version`,`status`),
  KEY `applicationname` (`bundleidentifier`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
