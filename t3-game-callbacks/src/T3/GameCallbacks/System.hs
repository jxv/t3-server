module T3.GameCallbacks.System
  ( Env(..)
  , Callbacks(..)
  , System
  , io
  ) where

import qualified Control.Concurrent as IO
import qualified Control.Monad.STM as IO
import Control.Concurrent.Async (race)
import Control.Monad.Trans.Maybe (MaybeT(..))
import Control.Monad.State (StateT(..), MonadState(..), gets, evalStateT)
import Control.Monad.Reader (ReaderT(..), MonadReader(..), asks)
import Control.Monad.IO.Class (MonadIO(..))
import Data.Functor (void)

import qualified T3.Game.BoardManagerImpl as BoardManager (isOpenLoc, getResult)
import T3.Core (Loc, Action, Board, Result, XO(..), emptyBoard)
import T3.Game.Run (run)
import T3.Game.Parts (Control(..), HasBoard(..), BoardManager(..))

import qualified T3.GameCallbacks.ConsoleImpl as Console
import qualified T3.GameCallbacks.ControlImpl as Control
import qualified T3.GameCallbacks.CommunicatorImpl as Communicator
import qualified T3.GameCallbacks.BoardManagerImpl as BoardManager (insertAtLoc)
import T3.GameCallbacks.Types (Step(..))
import T3.GameCallbacks.Milliseconds (Milliseconds(..), delay)
import T3.GameCallbacks.Parts
  ( Communicator(..)
  , Transmitter(..)
  , Finalizer(..)
  , HasActions(..)
  , Stoppable(..)
  , OnTimeout(..)
  , HasTimeoutLimit(..)
  , Console(..)
  )

newtype System a = System { unSystem :: MaybeT (ReaderT Env (StateT Data IO)) a }
  deriving (Functor, Applicative, Monad, MonadIO, MonadReader Env, MonadState Data)

data Env = Env
  { _callbacks :: XO -> Callbacks
  , _timeoutLimit :: Maybe Milliseconds
  , _finalize :: [Action] -> Board -> Result -> IO ()
  }

data Callbacks = Callbacks
  { _callbacksRecv :: IO Loc
  , _callbacksSend :: Step -> IO ()
  }

data Data = Data
  { _board :: Board
  , _actions :: [Action]
  } deriving (Show, Eq)

allSystemsGo :: System a -> Env -> Data -> IO (Maybe a, Data)
allSystemsGo system env dat = runStateT (runReaderT (runMaybeT (unSystem system)) env) dat

io :: System () -> Env -> IO ()
io system env = void $ allSystemsGo system env Data{ _board = emptyBoard, _actions = [] }

instance Control System where
  move = Control.move
  forfeit = Control.forfeit
  end = Control.end
  tie = Control.tie

instance BoardManager System where
  isOpenLoc = BoardManager.isOpenLoc
  insertAtLoc = BoardManager.insertAtLoc
  getResult = BoardManager.getResult

instance Communicator System where
  sendGameState = Communicator.sendGameState
  recvAction = Communicator.recvAction
  sendFinal = Communicator.sendFinal
  tally = Communicator.tally
  updateBoard = Communicator.updateBoard
  logAction = Communicator.logAction

instance Stoppable System where
  stop = System . MaybeT $ return Nothing

instance HasBoard System where
  getBoard = gets _board
  putBoard board = do
    dat <- get
    put dat{ _board = board }

instance HasActions System where
  getActions = gets _actions
  putActions actions = do
    matchState <- get
    put matchState{ _actions = actions }

instance Transmitter System where
  sendStep xo step = do
    send <- asks (_callbacksSend . flip _callbacks xo)
    liftIO $ send step
  recvLoc xo = do
    recv <- asks (_callbacksRecv . flip _callbacks xo)
    liftIO recv

instance Finalizer System where
  finalize actions board result = do
    f <- asks _finalize
    liftIO $ f actions board result

instance OnTimeout System where
  onTimeout system ms = do
    env <- ask
    dat <- get
    eitherOfMaybeAndData <- liftIO $ race (liftIO $ delay ms) (liftIO $ allSystemsGo system env dat)
    case eitherOfMaybeAndData of
      Left _ -> return Nothing
      Right (maybeA, dat') -> do
        put dat'
        return maybeA

instance HasTimeoutLimit System where
  getTimeoutLimit = asks _timeoutLimit

instance Console System where
  printStdout = Console.printStdout