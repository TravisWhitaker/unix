{-# LANGUAGE CApiFFI #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE Trustworthy #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  System.Posix.Terminal.Common
-- Copyright   :  (c) The University of Glasgow 2002
-- License     :  BSD-style (see the file libraries/base/LICENSE)
--
-- Maintainer  :  libraries@haskell.org
-- Stability   :  provisional
-- Portability :  non-portable (requires POSIX)
--
-- POSIX Terminal support
--
-----------------------------------------------------------------------------

-- see https://android.googlesource.com/platform/bionic/+/9ae59c0/libc/bionic/pathconf.c#37
#if !defined(_POSIX_VDISABLE) && defined(__ANDROID__)
#define _POSIX_VDISABLE -1
#endif


module System.Posix.Terminal.Common (
  -- * Terminal support

  -- ** Terminal attributes
  TerminalAttributes,
  getTerminalAttributes,
  TerminalState(..),
  setTerminalAttributes,

  CTermios,
  TerminalMode(..),
  withoutMode,
  withMode,
  terminalMode,
  bitsPerByte,
  withBits,

  ControlCharacter(..),
  controlChar,
  withCC,
  withoutCC,

  inputTime,
  withTime,
  minInput,
  withMinInput,

  BaudRate,
#ifdef B0
  pattern B0,
#endif
#ifdef B50
  pattern B50,
#endif
#ifdef B75
  pattern B75,
#endif
#ifdef B110
  pattern B110,
#endif
#ifdef B134
  pattern B134,
#endif
#ifdef B150
  pattern B150,
#endif
#ifdef B200
  pattern B200,
#endif
#ifdef B300
  pattern B300,
#endif
#ifdef B600
  pattern B600,
#endif
#ifdef B1200
  pattern B1200,
#endif
#ifdef B1800
  pattern B1800,
#endif
#ifdef B2400
  pattern B2400,
#endif
#ifdef B4800
  pattern B4800,
#endif
#ifdef B9600
  pattern B9600,
#endif
#ifdef B19200
  pattern B19200,
#endif
#ifdef B38400
  pattern B38400,
#endif
#ifdef B57600
  pattern B57600,
#endif
#ifdef B115200
  pattern B115200,
#endif
#ifdef B230400
  pattern B230400,
#endif
#ifdef B460800
  pattern B460800,
#endif
#ifdef B500000
  pattern B500000,
#endif
#ifdef B576000
  pattern B576000,
#endif
#ifdef B921600
  pattern B921600,
#endif
#ifdef B1000000
  pattern B1000000,
#endif
#ifdef B1152000
  pattern B1152000,
#endif
#ifdef B1500000
  pattern B1500000,
#endif
#ifdef B2000000
  pattern B2000000,
#endif
#ifdef B2500000
  pattern B2500000,
#endif
#ifdef B3000000
  pattern B3000000,
#endif
#ifdef B3500000
  pattern B3500000,
#endif
#ifdef B4000000
  pattern B4000000,
#endif
  inputSpeed,
  withInputSpeed,
  outputSpeed,
  withOutputSpeed,

  -- ** Terminal operations
  sendBreak,
  drainOutput,
  QueueSelector(..),
  discardData,
  FlowAction(..),
  controlFlow,

  -- ** Process groups
  getTerminalProcessGroupID,
  setTerminalProcessGroupID,

  -- ** Testing a file descriptor
  queryTerminal,
  ) where

#include "HsUnix.h"

import Data.Bits
import Data.Char
import Data.Coerce
import Foreign.C.Error ( throwErrnoIfMinus1, throwErrnoIfMinus1_ )
import Foreign.C.Types
import Foreign.ForeignPtr ( ForeignPtr, withForeignPtr, mallocForeignPtrBytes )
import Foreign.Marshal.Utils ( copyBytes )
import Foreign.Ptr ( Ptr, plusPtr )
import Foreign.Storable ( Storable(..) )
import System.IO.Unsafe ( unsafePerformIO )
import System.Posix.Types
import System.Posix.Internals ( CTermios )

#if !HAVE_TCDRAIN
import System.IO.Error ( ioeSetLocation )
import GHC.IO.Exception ( unsupportedOperation )
#endif

-- -----------------------------------------------------------------------------
-- Terminal attributes

newtype TerminalAttributes = TerminalAttributes (ForeignPtr CTermios)

makeTerminalAttributes :: ForeignPtr CTermios -> TerminalAttributes
makeTerminalAttributes = TerminalAttributes

withTerminalAttributes :: TerminalAttributes -> (Ptr CTermios -> IO a) -> IO a
withTerminalAttributes (TerminalAttributes termios) = withForeignPtr termios


data TerminalMode
        -- input flags
   = InterruptOnBreak           -- ^ @BRKINT@ - Signal interrupt on break
   | MapCRtoLF                  -- ^ @ICRNL@ - Map CR to NL on input
   | IgnoreBreak                -- ^ @IGNBRK@ - Ignore break condition
   | IgnoreCR                   -- ^ @IGNCR@ - Ignore CR
   | IgnoreParityErrors         -- ^ @IGNPAR@ - Ignore characters with parity errors
   | MapLFtoCR                  -- ^ @INLCR@ - Map NL to CR on input
   | CheckParity                -- ^ @INPCK@ - Enable input parity check
   | StripHighBit               -- ^ @ISTRIP@ - Strip character
   | RestartOnAny               -- ^ @IXANY@ - Enable any character to restart output
   | StartStopInput             -- ^ @IXOFF@ - Enable start/stop input control
   | StartStopOutput            -- ^ @IXON@ - Enable start/stop output control
   | MarkParityErrors           -- ^ @PARMRK@ - Mark parity errors

        -- output flags
   | ProcessOutput              -- ^ @OPOST@ - Post-process output
   | MapLFtoCRLF                -- ^ @ONLCR@ - (XSI) Map NL to CR-NL on output
                                --
                                -- @since 2.8.0.0
   | OutputMapCRtoLF            -- ^ @OCRNL@ - (XSI) Map CR to NL on output
                                --
                                -- @since 2.8.0.0
   | NoCRAtColumnZero           -- ^ @ONOCR@ - (XSI) No CR output at column 0
                                --
                                -- @since 2.8.0.0
   | ReturnMeansLF              -- ^ @ONLRET@ - (XSI) NL performs CR function
                                --
                                -- @since 2.8.0.0
   | TabDelayMask0              -- ^ @TABDLY(TAB0)@ - (XSI) Select horizontal-tab delays: type 0
                                --
                                -- @since 2.8.0.0
   | TabDelayMask3              -- ^ @TABDLY(TAB3)@ - (XSI) Select horizontal-tab delays: type 3
                                --
                                -- @since 2.8.0.0

        -- control flags
   | LocalMode                  -- ^ @CLOCAL@ - Ignore modem status lines
   | ReadEnable                 -- ^ @CREAD@ - Enable receiver
   | TwoStopBits                -- ^ @CSTOPB@ - Send two stop bits, else one
   | HangupOnClose              -- ^ @HUPCL@ - Hang up on last close
   | EnableParity               -- ^ @PARENB@ - Parity enable
   | OddParity                  -- ^ @PARODD@ - Odd parity, else even

        -- local modes
   | EnableEcho                 -- ^ @ECHO@ - Enable echo
   | EchoErase                  -- ^ @ECHOE@ - Echo erase character as error-correcting backspace
   | EchoKill                   -- ^ @ECHOK@ - Echo KILL
   | EchoLF                     -- ^ @ECHONL@ - Echo NL
   | ProcessInput               -- ^ @ICANON@ - Canonical input (erase and kill processing)
   | ExtendedFunctions          -- ^ @IEXTEN@ - Enable extended input character processing
   | KeyboardInterrupts         -- ^ @ISIG@ - Enable signals
   | NoFlushOnInterrupt         -- ^ @NOFLSH@ - Disable flush after interrupt or quit
   | BackgroundWriteInterrupt   -- ^ @TOSTOP@ - Send @SIGTTOU@ for background output

withoutMode :: TerminalAttributes -> TerminalMode -> TerminalAttributes
withoutMode termios InterruptOnBreak = clearInputFlag (#const BRKINT) termios
withoutMode termios MapCRtoLF = clearInputFlag (#const ICRNL) termios
withoutMode termios IgnoreBreak = clearInputFlag (#const IGNBRK) termios
withoutMode termios IgnoreCR = clearInputFlag (#const IGNCR) termios
withoutMode termios IgnoreParityErrors = clearInputFlag (#const IGNPAR) termios
withoutMode termios MapLFtoCR = clearInputFlag (#const INLCR) termios
withoutMode termios CheckParity = clearInputFlag (#const INPCK) termios
withoutMode termios StripHighBit = clearInputFlag (#const ISTRIP) termios
withoutMode termios RestartOnAny = clearInputFlag (#const IXANY) termios
withoutMode termios StartStopInput = clearInputFlag (#const IXOFF) termios
withoutMode termios StartStopOutput = clearInputFlag (#const IXON) termios
withoutMode termios MarkParityErrors = clearInputFlag (#const PARMRK) termios
withoutMode termios ProcessOutput = clearOutputFlag (#const OPOST) termios
withoutMode termios MapLFtoCRLF = clearOutputFlag (#const ONLCR) termios
withoutMode termios OutputMapCRtoLF = clearOutputFlag (#const OCRNL) termios
withoutMode termios NoCRAtColumnZero = clearOutputFlag (#const ONOCR) termios
withoutMode termios ReturnMeansLF = clearOutputFlag (#const ONLRET) termios
withoutMode termios TabDelayMask0 = clearOutputFlag (#const TAB0) termios
withoutMode termios TabDelayMask3 = clearOutputFlag (#const TAB3) termios
withoutMode termios LocalMode = clearControlFlag (#const CLOCAL) termios
withoutMode termios ReadEnable = clearControlFlag (#const CREAD) termios
withoutMode termios TwoStopBits = clearControlFlag (#const CSTOPB) termios
withoutMode termios HangupOnClose = clearControlFlag (#const HUPCL) termios
withoutMode termios EnableParity = clearControlFlag (#const PARENB) termios
withoutMode termios OddParity = clearControlFlag (#const PARODD) termios
withoutMode termios EnableEcho = clearLocalFlag (#const ECHO) termios
withoutMode termios EchoErase = clearLocalFlag (#const ECHOE) termios
withoutMode termios EchoKill = clearLocalFlag (#const ECHOK) termios
withoutMode termios EchoLF = clearLocalFlag (#const ECHONL) termios
withoutMode termios ProcessInput = clearLocalFlag (#const ICANON) termios
withoutMode termios ExtendedFunctions = clearLocalFlag (#const IEXTEN) termios
withoutMode termios KeyboardInterrupts = clearLocalFlag (#const ISIG) termios
withoutMode termios NoFlushOnInterrupt = setLocalFlag (#const NOFLSH) termios
withoutMode termios BackgroundWriteInterrupt = clearLocalFlag (#const TOSTOP) termios

withMode :: TerminalAttributes -> TerminalMode -> TerminalAttributes
withMode termios InterruptOnBreak = setInputFlag (#const BRKINT) termios
withMode termios MapCRtoLF = setInputFlag (#const ICRNL) termios
withMode termios IgnoreBreak = setInputFlag (#const IGNBRK) termios
withMode termios IgnoreCR = setInputFlag (#const IGNCR) termios
withMode termios IgnoreParityErrors = setInputFlag (#const IGNPAR) termios
withMode termios MapLFtoCR = setInputFlag (#const INLCR) termios
withMode termios CheckParity = setInputFlag (#const INPCK) termios
withMode termios StripHighBit = setInputFlag (#const ISTRIP) termios
withMode termios RestartOnAny = setInputFlag (#const IXANY) termios
withMode termios StartStopInput = setInputFlag (#const IXOFF) termios
withMode termios StartStopOutput = setInputFlag (#const IXON) termios
withMode termios MarkParityErrors = setInputFlag (#const PARMRK) termios
withMode termios ProcessOutput = setOutputFlag (#const OPOST) termios
withMode termios MapLFtoCRLF = setOutputFlag (#const ONLCR) termios
withMode termios OutputMapCRtoLF = setOutputFlag (#const OCRNL) termios
withMode termios NoCRAtColumnZero = setOutputFlag (#const ONOCR) termios
withMode termios ReturnMeansLF = setOutputFlag (#const ONLRET) termios
withMode termios TabDelayMask0 = setOutputFlag (#const TAB0) termios
withMode termios TabDelayMask3 = setOutputFlag (#const TAB3) termios
withMode termios LocalMode = setControlFlag (#const CLOCAL) termios
withMode termios ReadEnable = setControlFlag (#const CREAD) termios
withMode termios TwoStopBits = setControlFlag (#const CSTOPB) termios
withMode termios HangupOnClose = setControlFlag (#const HUPCL) termios
withMode termios EnableParity = setControlFlag (#const PARENB) termios
withMode termios OddParity = setControlFlag (#const PARODD) termios
withMode termios EnableEcho = setLocalFlag (#const ECHO) termios
withMode termios EchoErase = setLocalFlag (#const ECHOE) termios
withMode termios EchoKill = setLocalFlag (#const ECHOK) termios
withMode termios EchoLF = setLocalFlag (#const ECHONL) termios
withMode termios ProcessInput = setLocalFlag (#const ICANON) termios
withMode termios ExtendedFunctions = setLocalFlag (#const IEXTEN) termios
withMode termios KeyboardInterrupts = setLocalFlag (#const ISIG) termios
withMode termios NoFlushOnInterrupt = clearLocalFlag (#const NOFLSH) termios
withMode termios BackgroundWriteInterrupt = setLocalFlag (#const TOSTOP) termios

terminalMode :: TerminalMode -> TerminalAttributes -> Bool
terminalMode InterruptOnBreak = testInputFlag (#const BRKINT)
terminalMode MapCRtoLF = testInputFlag (#const ICRNL)
terminalMode IgnoreBreak = testInputFlag (#const IGNBRK)
terminalMode IgnoreCR = testInputFlag (#const IGNCR)
terminalMode IgnoreParityErrors = testInputFlag (#const IGNPAR)
terminalMode MapLFtoCR = testInputFlag (#const INLCR)
terminalMode CheckParity = testInputFlag (#const INPCK)
terminalMode StripHighBit = testInputFlag (#const ISTRIP)
terminalMode RestartOnAny = testInputFlag (#const IXANY)
terminalMode StartStopInput = testInputFlag (#const IXOFF)
terminalMode StartStopOutput = testInputFlag (#const IXON)
terminalMode MarkParityErrors = testInputFlag (#const PARMRK)
terminalMode ProcessOutput = testOutputFlag (#const OPOST)
terminalMode MapLFtoCRLF = testOutputFlag (#const ONLCR)
terminalMode OutputMapCRtoLF = testOutputFlag (#const OCRNL)
terminalMode NoCRAtColumnZero = testOutputFlag (#const ONOCR)
terminalMode ReturnMeansLF = testOutputFlag (#const ONLRET)
terminalMode TabDelayMask0 = testOutputFlag (#const TAB0)
terminalMode TabDelayMask3 = testOutputFlag (#const TAB3)
terminalMode LocalMode = testControlFlag (#const CLOCAL)
terminalMode ReadEnable = testControlFlag (#const CREAD)
terminalMode TwoStopBits = testControlFlag (#const CSTOPB)
terminalMode HangupOnClose = testControlFlag (#const HUPCL)
terminalMode EnableParity = testControlFlag (#const PARENB)
terminalMode OddParity = testControlFlag (#const PARODD)
terminalMode EnableEcho = testLocalFlag (#const ECHO)
terminalMode EchoErase = testLocalFlag (#const ECHOE)
terminalMode EchoKill = testLocalFlag (#const ECHOK)
terminalMode EchoLF = testLocalFlag (#const ECHONL)
terminalMode ProcessInput = testLocalFlag (#const ICANON)
terminalMode ExtendedFunctions = testLocalFlag (#const IEXTEN)
terminalMode KeyboardInterrupts = testLocalFlag (#const ISIG)
terminalMode NoFlushOnInterrupt = not . testLocalFlag (#const NOFLSH)
terminalMode BackgroundWriteInterrupt = testLocalFlag (#const TOSTOP)

bitsPerByte :: TerminalAttributes -> Int
bitsPerByte termios = unsafePerformIO $ do
  withTerminalAttributes termios $ \p -> do
    cflag <- (#peek struct termios, c_cflag) p
    return $! (word2Bits (cflag .&. (#const CSIZE)))
  where
    word2Bits :: CTcflag -> Int
    word2Bits x =
        if x == (#const CS5) then 5
        else if x == (#const CS6) then 6
        else if x == (#const CS7) then 7
        else if x == (#const CS8) then 8
        else 0

withBits :: TerminalAttributes -> Int -> TerminalAttributes
withBits termios bits = unsafePerformIO $ do
  withNewTermios termios $ \p -> do
    cflag <- (#peek struct termios, c_cflag) p
    (#poke struct termios, c_cflag) p
       ((cflag .&. complement (#const CSIZE)) .|. mask bits)
  where
    mask :: Int -> CTcflag
    mask 5 = (#const CS5)
    mask 6 = (#const CS6)
    mask 7 = (#const CS7)
    mask 8 = (#const CS8)
    mask _ = error "withBits bit value out of range [5..8]"

data ControlCharacter
  = EndOfFile           -- VEOF
  | EndOfLine           -- VEOL
  | Erase               -- VERASE
  | Interrupt           -- VINTR
  | Kill                -- VKILL
  | Quit                -- VQUIT
  | Start               -- VSTART
  | Stop                -- VSTOP
  | Suspend             -- VSUSP

controlChar :: TerminalAttributes -> ControlCharacter -> Maybe Char
controlChar termios cc = unsafePerformIO $ do
  withTerminalAttributes termios $ \p -> do
    let c_cc = (#ptr struct termios, c_cc) p
    val <- peekElemOff c_cc (cc2Word cc)
    if val == ((#const _POSIX_VDISABLE)::CCc)
       then return Nothing
       else return (Just (chr (fromEnum val)))

withCC :: TerminalAttributes
       -> (ControlCharacter, Char)
       -> TerminalAttributes
withCC termios (cc, c) = unsafePerformIO $ do
  withNewTermios termios $ \p -> do
    let c_cc = (#ptr struct termios, c_cc) p
    pokeElemOff c_cc (cc2Word cc) (fromIntegral (ord c) :: CCc)

withoutCC :: TerminalAttributes
          -> ControlCharacter
          -> TerminalAttributes
withoutCC termios cc = unsafePerformIO $ do
  withNewTermios termios $ \p -> do
    let c_cc = (#ptr struct termios, c_cc) p
    pokeElemOff c_cc (cc2Word cc) ((#const _POSIX_VDISABLE) :: CCc)

inputTime :: TerminalAttributes -> Int
inputTime termios = unsafePerformIO $ do
  withTerminalAttributes termios $ \p -> do
    c <- peekElemOff ((#ptr struct termios, c_cc) p) (#const VTIME)
    return (fromEnum (c :: CCc))

withTime :: TerminalAttributes -> Int -> TerminalAttributes
withTime termios time = unsafePerformIO $ do
  withNewTermios termios $ \p -> do
    let c_cc = (#ptr struct termios, c_cc) p
    pokeElemOff c_cc (#const VTIME) (fromIntegral time :: CCc)

minInput :: TerminalAttributes -> Int
minInput termios = unsafePerformIO $ do
  withTerminalAttributes termios $ \p -> do
    c <- peekElemOff ((#ptr struct termios, c_cc) p) (#const VMIN)
    return (fromEnum (c :: CCc))

withMinInput :: TerminalAttributes -> Int -> TerminalAttributes
withMinInput termios count = unsafePerformIO $ do
  withNewTermios termios $ \p -> do
    let c_cc = (#ptr struct termios, c_cc) p
    pokeElemOff c_cc (#const VMIN) (fromIntegral count :: CCc)

newtype BaudRate = BaudRate CSpeed

#ifdef B0
pattern B0 :: BaudRate
pattern B0 = BaudRate (#const B0)
#endif
#ifdef B50
pattern B50 :: BaudRate
pattern B50 = BaudRate (#const B50)
#endif
#ifdef B75
pattern B75 :: BaudRate
pattern B75 = BaudRate (#const B75)
#endif
#ifdef B110
pattern B110 :: BaudRate
pattern B110 = BaudRate (#const B110)
#endif
#ifdef B134
pattern B134 :: BaudRate
pattern B134 = BaudRate (#const B134)
#endif
#ifdef B150
pattern B150 :: BaudRate
pattern B150 = BaudRate (#const B150)
#endif
#ifdef B200
pattern B200 :: BaudRate
pattern B200 = BaudRate (#const B200)
#endif
#ifdef B300
pattern B300 :: BaudRate
pattern B300 = BaudRate (#const B300)
#endif
#ifdef B600
pattern B600 :: BaudRate
pattern B600 = BaudRate (#const B600)
#endif
#ifdef B1200
pattern B1200 :: BaudRate
pattern B1200 = BaudRate (#const B1200)
#endif
#ifdef B1800
pattern B1800 :: BaudRate
pattern B1800 = BaudRate (#const B1800)
#endif
#ifdef B2400
pattern B2400 :: BaudRate
pattern B2400 = BaudRate (#const B2400)
#endif
#ifdef B4800
pattern B4800 :: BaudRate
pattern B4800 = BaudRate (#const B4800)
#endif
#ifdef B9600
pattern B9600 :: BaudRate
pattern B9600 = BaudRate (#const B9600)
#endif
#ifdef B19200
pattern B19200 :: BaudRate
pattern B19200 = BaudRate (#const B19200)
#endif
#ifdef B38400
pattern B38400 :: BaudRate
pattern B38400 = BaudRate (#const B38400)
#endif
#ifdef B57600
pattern B57600 :: BaudRate
pattern B57600 = BaudRate (#const B57600)
#endif
#ifdef B115200
pattern B115200 :: BaudRate
pattern B115200 = BaudRate (#const B115200)
#endif
#ifdef B230400
pattern B230400 :: BaudRate
pattern B230400 = BaudRate (#const B230400)
#endif
#ifdef B460800
pattern B460800 :: BaudRate
pattern B460800 = BaudRate (#const B460800)
#endif
#ifdef B500000
pattern B500000 :: BaudRate
pattern B500000 = BaudRate (#const B500000)
#endif
#ifdef B576000
pattern B576000 :: BaudRate
pattern B576000 = BaudRate (#const B576000)
#endif
#ifdef B921600
pattern B921600 :: BaudRate
pattern B921600 = BaudRate (#const B921600)
#endif
#ifdef B1000000
pattern B1000000 :: BaudRate
pattern B1000000 = BaudRate (#const B1000000)
#endif
#ifdef B1152000
pattern B1152000 :: BaudRate
pattern B1152000 = BaudRate (#const B1152000)
#endif
#ifdef B1500000
pattern B1500000 :: BaudRate
pattern B1500000 = BaudRate (#const B1500000)
#endif
#ifdef B2000000
pattern B2000000 :: BaudRate
pattern B2000000 = BaudRate (#const B2000000)
#endif
#ifdef B2500000
pattern B2500000 :: BaudRate
pattern B2500000 = BaudRate (#const B2500000)
#endif
#ifdef B3000000
pattern B3000000 :: BaudRate
pattern B3000000 = BaudRate (#const B3000000)
#endif
#ifdef B3500000
pattern B3500000 :: BaudRate
pattern B3500000 = BaudRate (#const B3500000)
#endif
#ifdef B4000000
pattern B4000000 :: BaudRate
pattern B4000000 = BaudRate (#const B4000000)
#endif

inputSpeed :: TerminalAttributes -> BaudRate
inputSpeed termios = unsafePerformIO $ do
  withTerminalAttributes termios $ \p -> do
    w <- c_cfgetispeed p
    return (word2Baud w)

foreign import capi unsafe "termios.h cfgetispeed"
  c_cfgetispeed :: Ptr CTermios -> IO CSpeed

withInputSpeed :: TerminalAttributes -> BaudRate -> TerminalAttributes
withInputSpeed termios br = unsafePerformIO $ do
  withNewTermios termios $ \p -> c_cfsetispeed p (baud2Word br)

foreign import capi unsafe "termios.h cfsetispeed"
  c_cfsetispeed :: Ptr CTermios -> CSpeed -> IO CInt


outputSpeed :: TerminalAttributes -> BaudRate
outputSpeed termios = unsafePerformIO $ do
  withTerminalAttributes termios $ \p ->  do
    w <- c_cfgetospeed p
    return (word2Baud w)

foreign import capi unsafe "termios.h cfgetospeed"
  c_cfgetospeed :: Ptr CTermios -> IO CSpeed

withOutputSpeed :: TerminalAttributes -> BaudRate -> TerminalAttributes
withOutputSpeed termios br = unsafePerformIO $ do
  withNewTermios termios $ \p -> c_cfsetospeed p (baud2Word br)

foreign import capi unsafe "termios.h cfsetospeed"
  c_cfsetospeed :: Ptr CTermios -> CSpeed -> IO CInt

-- | @getTerminalAttributes fd@ calls @tcgetattr@ to obtain
--   the @TerminalAttributes@ associated with @Fd@ @fd@.
getTerminalAttributes :: Fd -> IO TerminalAttributes
getTerminalAttributes (Fd fd) = do
  fp <- mallocForeignPtrBytes (#const sizeof(struct termios))
  withForeignPtr fp $ \p ->
      throwErrnoIfMinus1_ "getTerminalAttributes" (c_tcgetattr fd p)
  return $ makeTerminalAttributes fp

foreign import capi unsafe "termios.h tcgetattr"
  c_tcgetattr :: CInt -> Ptr CTermios -> IO CInt

data TerminalState
  = Immediately
  | WhenDrained
  | WhenFlushed

-- | @setTerminalAttributes fd attr ts@ calls @tcsetattr@ to change
--   the @TerminalAttributes@ associated with @Fd@ @fd@ to
--   @attr@, when the terminal is in the state indicated by @ts@.
setTerminalAttributes :: Fd
                      -> TerminalAttributes
                      -> TerminalState
                      -> IO ()
setTerminalAttributes (Fd fd) termios state = do
  withTerminalAttributes termios $ \p ->
    throwErrnoIfMinus1_ "setTerminalAttributes"
      (c_tcsetattr fd (state2Int state) p)
  where
    state2Int :: TerminalState -> CInt
    state2Int Immediately = (#const TCSANOW)
    state2Int WhenDrained = (#const TCSADRAIN)
    state2Int WhenFlushed = (#const TCSAFLUSH)

foreign import capi unsafe "termios.h tcsetattr"
   c_tcsetattr :: CInt -> CInt -> Ptr CTermios -> IO CInt

-- | @sendBreak fd duration@ calls @tcsendbreak@ to transmit a
--   continuous stream of zero-valued bits on @Fd@ @fd@ for the
--   specified implementation-dependent @duration@.
sendBreak :: Fd -> Int -> IO ()
sendBreak (Fd fd) duration
  = throwErrnoIfMinus1_ "sendBreak" (c_tcsendbreak fd (fromIntegral duration))

foreign import capi unsafe "termios.h tcsendbreak"
  c_tcsendbreak :: CInt -> CInt -> IO CInt

-- | @drainOutput fd@ calls @tcdrain@ to block until all output
--   written to @Fd@ @fd@ has been transmitted.
--
-- Throws 'IOError' (\"unsupported operation\") if platform does not
-- provide @tcdrain(3)@ (use @#if HAVE_TCDRAIN@ CPP guard to
-- detect availability).
drainOutput :: Fd -> IO ()
#if HAVE_TCDRAIN
drainOutput (Fd fd) = throwErrnoIfMinus1_ "drainOutput" (c_tcdrain fd)

foreign import capi safe "termios.h tcdrain"
  c_tcdrain :: CInt -> IO CInt
#else
{-# WARNING drainOutput
    "operation will throw 'IOError' \"unsupported operation\" (CPP guard: @#if HAVE_TCDRAIN@)" #-}
drainOutput _ = ioError (ioeSetLocation unsupportedOperation "drainOutput")
#endif

data QueueSelector
  = InputQueue          -- TCIFLUSH
  | OutputQueue         -- TCOFLUSH
  | BothQueues          -- TCIOFLUSH

-- | @discardData fd queues@ calls @tcflush@ to discard
--   pending input and\/or output for @Fd@ @fd@,
--   as indicated by the @QueueSelector@ @queues@.
discardData :: Fd -> QueueSelector -> IO ()
discardData (Fd fd) queue =
  throwErrnoIfMinus1_ "discardData" (c_tcflush fd (queue2Int queue))
  where
    queue2Int :: QueueSelector -> CInt
    queue2Int InputQueue  = (#const TCIFLUSH)
    queue2Int OutputQueue = (#const TCOFLUSH)
    queue2Int BothQueues  = (#const TCIOFLUSH)

foreign import capi unsafe "termios.h tcflush"
  c_tcflush :: CInt -> CInt -> IO CInt

data FlowAction
  = SuspendOutput       -- ^ TCOOFF
  | RestartOutput       -- ^ TCOON
  | TransmitStop        -- ^ TCIOFF
  | TransmitStart       -- ^ TCION

-- | @controlFlow fd action@ calls @tcflow@ to control the
--   flow of data on @Fd@ @fd@, as indicated by
--   @action@.
controlFlow :: Fd -> FlowAction -> IO ()
controlFlow (Fd fd) action =
  throwErrnoIfMinus1_ "controlFlow" (c_tcflow fd (action2Int action))
  where
    action2Int :: FlowAction -> CInt
    action2Int SuspendOutput = (#const TCOOFF)
    action2Int RestartOutput = (#const TCOON)
    action2Int TransmitStop  = (#const TCIOFF)
    action2Int TransmitStart = (#const TCION)

foreign import capi unsafe "termios.h tcflow"
  c_tcflow :: CInt -> CInt -> IO CInt

-- | @getTerminalProcessGroupID fd@ calls @tcgetpgrp@ to
--   obtain the @ProcessGroupID@ of the foreground process group
--   associated with the terminal attached to @Fd@ @fd@.
getTerminalProcessGroupID :: Fd -> IO ProcessGroupID
getTerminalProcessGroupID (Fd fd) = do
  throwErrnoIfMinus1 "getTerminalProcessGroupID" (c_tcgetpgrp fd)

foreign import ccall unsafe "tcgetpgrp"
  c_tcgetpgrp :: CInt -> IO CPid

-- | @setTerminalProcessGroupID fd pgid@ calls @tcsetpgrp@ to
--   set the @ProcessGroupID@ of the foreground process group
--   associated with the terminal attached to @Fd@
--   @fd@ to @pgid@.
setTerminalProcessGroupID :: Fd -> ProcessGroupID -> IO ()
setTerminalProcessGroupID (Fd fd) pgid =
  throwErrnoIfMinus1_ "setTerminalProcessGroupID" (c_tcsetpgrp fd pgid)

foreign import ccall unsafe "tcsetpgrp"
  c_tcsetpgrp :: CInt -> CPid -> IO CInt

-- -----------------------------------------------------------------------------
-- file descriptor queries

-- | @queryTerminal fd@ calls @isatty@ to determine whether or
--   not @Fd@ @fd@ is associated with a terminal.
queryTerminal :: Fd -> IO Bool
queryTerminal (Fd fd) = do
  r <- c_isatty fd
  return (r == 1)
  -- ToDo: the spec says that it can set errno to EBADF if the result is zero

foreign import ccall unsafe "isatty"
  c_isatty :: CInt -> IO CInt

-- -----------------------------------------------------------------------------
-- Local utility functions

-- Convert Haskell ControlCharacter to Int

cc2Word :: ControlCharacter -> Int
cc2Word EndOfFile = (#const VEOF)
cc2Word EndOfLine = (#const VEOL)
cc2Word Erase     = (#const VERASE)
cc2Word Interrupt = (#const VINTR)
cc2Word Kill      = (#const VKILL)
cc2Word Quit      = (#const VQUIT)
cc2Word Suspend   = (#const VSUSP)
cc2Word Start     = (#const VSTART)
cc2Word Stop      = (#const VSTOP)

-- Convert Haskell BaudRate to unsigned integral type (Word)

baud2Word :: BaudRate -> CSpeed
baud2Word = coerce

-- And convert a word back to a baud rate
-- We really need some cpp macros here.

word2Baud :: CSpeed -> BaudRate
word2Baud x = case x of
#ifdef B0
    (#const B0) -> B0
#endif
#ifdef B50
    (#const B50) -> B50
#endif
#ifdef B75
    (#const B75) -> B75
#endif
#ifdef B110
    (#const B110) -> B110
#endif
#ifdef B134
    (#const B134) -> B134
#endif
#ifdef B150
    (#const B150) -> B150
#endif
#ifdef B200
    (#const B200) -> B200
#endif
#ifdef B300
    (#const B300) -> B300
#endif
#ifdef B600
    (#const B600) -> B600
#endif
#ifdef B1200
    (#const B1200) -> B1200
#endif
#ifdef B1800
    (#const B1800) -> B1800
#endif
#ifdef B2400
    (#const B2400) -> B2400
#endif
#ifdef B4800
    (#const B4800) -> B4800
#endif
#ifdef B9600
    (#const B9600) -> B9600
#endif
#ifdef B19200
    (#const B19200) -> B19200
#endif
#ifdef B38400
    (#const B38400) -> B38400
#endif
#ifdef B57600
    (#const B57600) -> B57600
#endif
#ifdef B115200
    (#const B115200) -> B115200
#endif
#ifdef B230400
    (#const B230400) -> B230400
#endif
#ifdef B460800
    (#const B460800) -> B460800
#endif
#ifdef B500000
    (#const B500000) -> B500000
#endif
#ifdef B576000
    (#const B576000) -> B576000
#endif
#ifdef B921600
    (#const B921600) -> B921600
#endif
#ifdef B1000000
    (#const B1000000) -> B1000000
#endif
#ifdef B1152000
    (#const B1152000) -> B1152000
#endif
#ifdef B1500000
    (#const B1500000) -> B1500000
#endif
#ifdef B2000000
    (#const B2000000) -> B2000000
#endif
#ifdef B2500000
    (#const B2500000) -> B2500000
#endif
#ifdef B3000000
    (#const B3000000) -> B3000000
#endif
#ifdef B3500000
    (#const B3500000) -> B3500000
#endif
#ifdef B4000000
    (#const B4000000) -> B4000000
#endif
    _                 -> error "unknown baud rate"

-- Clear termios i_flag

clearInputFlag :: CTcflag -> TerminalAttributes -> TerminalAttributes
clearInputFlag flag termios = unsafePerformIO $ do
  fp <- mallocForeignPtrBytes (#const sizeof(struct termios))
  withForeignPtr fp $ \p1 -> do
    withTerminalAttributes termios $ \p2 -> do
      copyBytes p1 p2 (#const sizeof(struct termios))
      iflag <- (#peek struct termios, c_iflag) p2
      (#poke struct termios, c_iflag) p1 (iflag .&. complement flag)
  return $ makeTerminalAttributes fp

-- Set termios i_flag

setInputFlag :: CTcflag -> TerminalAttributes -> TerminalAttributes
setInputFlag flag termios = unsafePerformIO $ do
  fp <- mallocForeignPtrBytes (#const sizeof(struct termios))
  withForeignPtr fp $ \p1 -> do
    withTerminalAttributes termios $ \p2 -> do
      copyBytes p1 p2 (#const sizeof(struct termios))
      iflag <- (#peek struct termios, c_iflag) p2
      (#poke struct termios, c_iflag) p1 (iflag .|. flag)
  return $ makeTerminalAttributes fp

-- Examine termios i_flag

testInputFlag :: CTcflag -> TerminalAttributes -> Bool
testInputFlag flag termios = unsafePerformIO $
  withTerminalAttributes termios $ \p ->  do
    iflag <- (#peek struct termios, c_iflag) p
    return $! ((iflag .&. flag) /= 0)

-- Clear termios c_flag

clearControlFlag :: CTcflag -> TerminalAttributes -> TerminalAttributes
clearControlFlag flag termios = unsafePerformIO $ do
  fp <- mallocForeignPtrBytes (#const sizeof(struct termios))
  withForeignPtr fp $ \p1 -> do
    withTerminalAttributes termios $ \p2 -> do
      copyBytes p1 p2 (#const sizeof(struct termios))
      cflag <- (#peek struct termios, c_cflag) p2
      (#poke struct termios, c_cflag) p1 (cflag .&. complement flag)
  return $ makeTerminalAttributes fp

-- Set termios c_flag

setControlFlag :: CTcflag -> TerminalAttributes -> TerminalAttributes
setControlFlag flag termios = unsafePerformIO $ do
  fp <- mallocForeignPtrBytes (#const sizeof(struct termios))
  withForeignPtr fp $ \p1 -> do
    withTerminalAttributes termios $ \p2 -> do
      copyBytes p1 p2 (#const sizeof(struct termios))
      cflag <- (#peek struct termios, c_cflag) p2
      (#poke struct termios, c_cflag) p1 (cflag .|. flag)
  return $ makeTerminalAttributes fp

-- Examine termios c_flag

testControlFlag :: CTcflag -> TerminalAttributes -> Bool
testControlFlag flag termios = unsafePerformIO $
  withTerminalAttributes termios $ \p -> do
    cflag <- (#peek struct termios, c_cflag) p
    return $! ((cflag .&. flag) /= 0)

-- Clear termios l_flag

clearLocalFlag :: CTcflag -> TerminalAttributes -> TerminalAttributes
clearLocalFlag flag termios = unsafePerformIO $ do
  fp <- mallocForeignPtrBytes (#const sizeof(struct termios))
  withForeignPtr fp $ \p1 -> do
    withTerminalAttributes termios $ \p2 -> do
      copyBytes p1 p2 (#const sizeof(struct termios))
      lflag <- (#peek struct termios, c_lflag) p2
      (#poke struct termios, c_lflag) p1 (lflag .&. complement flag)
  return $ makeTerminalAttributes fp

-- Set termios l_flag

setLocalFlag :: CTcflag -> TerminalAttributes -> TerminalAttributes
setLocalFlag flag termios = unsafePerformIO $ do
  fp <- mallocForeignPtrBytes (#const sizeof(struct termios))
  withForeignPtr fp $ \p1 -> do
    withTerminalAttributes termios $ \p2 -> do
      copyBytes p1 p2 (#const sizeof(struct termios))
      lflag <- (#peek struct termios, c_lflag) p2
      (#poke struct termios, c_lflag) p1 (lflag .|. flag)
  return $ makeTerminalAttributes fp

-- Examine termios l_flag

testLocalFlag :: CTcflag -> TerminalAttributes -> Bool
testLocalFlag flag termios = unsafePerformIO $
  withTerminalAttributes termios $ \p ->  do
    lflag <- (#peek struct termios, c_lflag) p
    return $! ((lflag .&. flag) /= 0)

-- Clear termios o_flag

clearOutputFlag :: CTcflag -> TerminalAttributes -> TerminalAttributes
clearOutputFlag flag termios = unsafePerformIO $ do
  fp <- mallocForeignPtrBytes (#const sizeof(struct termios))
  withForeignPtr fp $ \p1 -> do
    withTerminalAttributes termios $ \p2 -> do
      copyBytes p1 p2 (#const sizeof(struct termios))
      oflag <- (#peek struct termios, c_oflag) p2
      (#poke struct termios, c_oflag) p1 (oflag .&. complement flag)
  return $ makeTerminalAttributes fp

-- Set termios o_flag

setOutputFlag :: CTcflag -> TerminalAttributes -> TerminalAttributes
setOutputFlag flag termios = unsafePerformIO $ do
  fp <- mallocForeignPtrBytes (#const sizeof(struct termios))
  withForeignPtr fp $ \p1 -> do
    withTerminalAttributes termios $ \p2 -> do
      copyBytes p1 p2 (#const sizeof(struct termios))
      oflag <- (#peek struct termios, c_oflag) p2
      (#poke struct termios, c_oflag) p1 (oflag .|. flag)
  return $ makeTerminalAttributes fp

-- Examine termios o_flag

testOutputFlag :: CTcflag -> TerminalAttributes -> Bool
testOutputFlag flag termios = unsafePerformIO $
  withTerminalAttributes termios $ \p -> do
    oflag <- (#peek struct termios, c_oflag) p
    return $! ((oflag .&. flag) /= 0)

withNewTermios :: TerminalAttributes -> (Ptr CTermios -> IO a)
  -> IO TerminalAttributes
withNewTermios termios action = do
  fp1 <- mallocForeignPtrBytes (#const sizeof(struct termios))
  withForeignPtr fp1 $ \p1 -> do
   withTerminalAttributes termios $ \p2 -> do
    copyBytes p1 p2 (#const sizeof(struct termios))
    _ <- action p1
    return ()
  return $ makeTerminalAttributes fp1
