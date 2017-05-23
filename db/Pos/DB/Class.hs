{-# LANGUAGE Rank2Types   #-}
{-# LANGUAGE TypeFamilies #-}

-- | A set of type classes which provide access to database.
--
-- 'MonadDB' is the main class (actually just a set of constraints) which
-- wraps 'NodeDBs' which contains RocksDB databases. This class can be
-- used to manipulate RocksDB directly. It may be useful when you need
-- an access to advanced features of RocksDB.
--
-- Apart from that we have two more classes here.
--
-- 'MonadDBPure' contains only 'dbGet' method.  The advantage of it is
-- that you don't need to do any 'IO' to use it which makes it
-- suitable for pure testing.
-- TODO: add put to this monad (actually putBatch is more important).
--
-- 'MonadGStateCore' contains functions to retrieve some data from
-- GState DB without knowledge of where this data is located (where in
-- code and where in DB, i. e. by which key). For example, if X wants
-- to get data maintained by Y and doesn't know about Y, it can use
-- 'MonadGStateCore' (which is at pretty low level).

module Pos.DB.Class
       (
         -- * Pure
         DBTag (..)
       , dbTagToLens
       , MonadDBPure (..)

         -- * GState Core
       , MonadGStateCore (..)
       , gsMaxBlockSize
       , gsMaxHeaderSize
       , gsMaxTxSize
       , gsMaxProposalSize
       , MonadDBCore

         -- * RocksDB
       , MonadDB
       , getNodeDBs
       , usingReadOptions
       , usingWriteOptions
       , getBlockIndexDB
       , getGStateDB
       , getLrcDB
       , getMiscDB
       ) where

import           Universum

import           Control.Lens                   (ASetter')
import           Control.Monad.Trans            (MonadTrans (..))
import           Control.Monad.Trans.Lift.Local (LiftLocal (..))
import qualified Database.RocksDB               as Rocks
import qualified Ether
import           Serokell.Data.Memory.Units     (Byte)

import           Pos.Core                       (BlockVersionData (..))
import           Pos.DB.Types                   (DB (..), NodeDBs, blockIndexDB, gStateDB,
                                                 lrcDB, miscDB)

----------------------------------------------------------------------------
-- Pure
----------------------------------------------------------------------------

-- | Tag which denotes one of DBs used by application.
data DBTag
    = BlockIndexDB
    | GStateDB
    | LrcDB
    | MiscDB
    deriving (Eq)

dbTagToLens :: DBTag -> Lens' NodeDBs DB
dbTagToLens BlockIndexDB = blockIndexDB
dbTagToLens GStateDB     = gStateDB
dbTagToLens LrcDB        = lrcDB
dbTagToLens MiscDB       = miscDB

-- | Pure interface to the database.
-- TODO: add some ways to put something.
class MonadThrow m => MonadDBPure m where
    dbGet :: DBTag -> ByteString -> m (Maybe ByteString)

    default dbGet :: (MonadTrans t, MonadDBPure n, t n ~ m) =>
        DBTag -> ByteString -> m (Maybe ByteString)
    dbGet tag = lift . dbGet tag

instance {-# OVERLAPPABLE #-}
    (MonadDBPure m, MonadTrans t, MonadThrow (t m)) =>
        MonadDBPure (t m)

----------------------------------------------------------------------------
-- GState abstraction
----------------------------------------------------------------------------

-- | This type class provides functions to get core data from GState.
-- The idea is that actual getters may be defined at high levels, but
-- may be needed at lower levels.
--
-- This class doesn't have a 'MonadDB' constraint, because alternative
-- DBs my be used to provide this data. There is also 'MonadDBCore' constraint
-- which unites 'MonadDB' and 'GStateCore'.
class Monad m => MonadGStateCore m where
    gsAdoptedBVData :: m BlockVersionData

instance {-# OVERLAPPABLE #-}
    (MonadGStateCore m, MonadTrans t, LiftLocal t,
     Monad (t m)) =>
        MonadGStateCore (t m)
  where
    gsAdoptedBVData = lift gsAdoptedBVData

gsMaxBlockSize :: MonadGStateCore m => m Byte
gsMaxBlockSize = bvdMaxBlockSize <$> gsAdoptedBVData

gsMaxHeaderSize :: MonadGStateCore m => m Byte
gsMaxHeaderSize = bvdMaxHeaderSize <$> gsAdoptedBVData

gsMaxTxSize :: MonadGStateCore m => m Byte
gsMaxTxSize = bvdMaxTxSize <$> gsAdoptedBVData

gsMaxProposalSize :: MonadGStateCore m => m Byte
gsMaxProposalSize = bvdMaxProposalSize <$> gsAdoptedBVData

type MonadDBCore m = (MonadDB m, MonadGStateCore m)

----------------------------------------------------------------------------
-- RocksDB
----------------------------------------------------------------------------

type MonadDB m
     = (Ether.MonadReader' NodeDBs m, MonadIO m, MonadCatch m)

getNodeDBs :: MonadDB m => m NodeDBs
getNodeDBs = Ether.ask'

usingReadOptions
    :: MonadDB m
    => Rocks.ReadOptions
    -> ASetter' NodeDBs DB
    -> m a
    -> m a
usingReadOptions opts l =
    Ether.local' (over l (\db -> db {rocksReadOpts = opts}))

usingWriteOptions
    :: MonadDB m
    => Rocks.WriteOptions
    -> ASetter' NodeDBs DB
    -> m a
    -> m a
usingWriteOptions opts l =
    Ether.local' (over l (\db -> db {rocksWriteOpts = opts}))

getBlockIndexDB :: MonadDB m => m DB
getBlockIndexDB = view blockIndexDB <$> getNodeDBs

getGStateDB :: MonadDB m => m DB
getGStateDB = view gStateDB <$> getNodeDBs

getLrcDB :: MonadDB m => m DB
getLrcDB = view lrcDB <$> getNodeDBs

getMiscDB :: MonadDB m => m DB
getMiscDB = view miscDB <$> getNodeDBs
