/**
 * HistoryView — session list with activity filter, swipe-to-delete, shake-to-undo.
 * The 20-second undo banner shows when a session is pending delete.
 */

import React, { useState, useCallback, useRef, useEffect } from 'react';
import {
  View, Text, FlatList, TouchableOpacity, StyleSheet,
  Modal, Animated, PanResponder,
} from 'react-native';
import { useFitnessStore, Session, ActivityType } from '../../store/fitnessStore';
import { useShakeGesture } from '../../services/useShakeGesture';
import { recalculate } from '../../services/insightsEngine';
import { SessionRow } from './SessionRow';
import { SessionDetailView } from './SessionDetailView';
import { SessionEditorView } from './SessionEditorView';
import { OutdoorRunView } from './OutdoorRunView';
import { COLORS, SPACING, RADIUS, FONT_SIZE, FONT_WEIGHT } from '../../utils/constants';

const FILTERS: { key: ActivityType | 'all'; label: string }[] = [
  { key: 'all', label: 'All' },
  { key: 'treadmill', label: 'Treadmill' },
  { key: 'bike', label: 'Bike' },
  { key: 'outdoorRun', label: 'Outdoor' },
];

type Screen = 'list' | 'detail' | 'edit' | 'newSession' | 'run';

export function HistoryView(): React.JSX.Element {
  const { sessions, addSession, updateSession, deleteSession, undoDelete, clearPendingDelete, pendingDelete } = useFitnessStore();

  const [filter, setFilter] = useState<ActivityType | 'all'>('all');
  const [screen, setScreen] = useState<Screen>('list');
  const [selectedSession, setSelectedSession] = useState<Session | null>(null);

  // Shake to undo
  const undoTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [undoSecondsLeft, setUndoSecondsLeft] = useState(0);
  const countdownRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useShakeGesture(
    useCallback(() => {
      if (pendingDelete) {
        undoDelete();
        if (undoTimeoutRef.current) clearTimeout(undoTimeoutRef.current);
        if (countdownRef.current) clearInterval(countdownRef.current);
        setUndoSecondsLeft(0);
      }
    }, [pendingDelete, undoDelete])
  );

  // Start countdown when pendingDelete is set
  useEffect(() => {
    if (pendingDelete) {
      setUndoSecondsLeft(20);
      if (countdownRef.current) clearInterval(countdownRef.current);
      countdownRef.current = setInterval(() => {
        setUndoSecondsLeft((s) => {
          if (s <= 1) {
            clearInterval(countdownRef.current!);
            return 0;
          }
          return s - 1;
        });
      }, 1000);

      if (undoTimeoutRef.current) clearTimeout(undoTimeoutRef.current);
      undoTimeoutRef.current = setTimeout(() => {
        clearPendingDelete();
        setUndoSecondsLeft(0);
      }, 20000);
    } else {
      if (undoTimeoutRef.current) clearTimeout(undoTimeoutRef.current);
      if (countdownRef.current) clearInterval(countdownRef.current);
    }
    return () => {
      if (undoTimeoutRef.current) clearTimeout(undoTimeoutRef.current);
      if (countdownRef.current) clearInterval(countdownRef.current);
    };
  }, [pendingDelete, clearPendingDelete]);

  const filtered =
    filter === 'all' ? sessions : sessions.filter((s) => s.activityType === filter);

  const handleDelete = useCallback(
    async (id: string) => {
      await deleteSession(id);
      recalculate();
      setScreen('list');
    },
    [deleteSession]
  );

  const handleSaveNew = useCallback(
    async (session: Session) => {
      await addSession(session);
      recalculate();
      setScreen('list');
    },
    [addSession]
  );

  const handleSaveEdit = useCallback(
    async (session: Session) => {
      await updateSession(session);
      recalculate();
      setSelectedSession(session);
      setScreen('detail');
    },
    [updateSession]
  );

  // ── Detail / Editor modals ────────────────────────────────────────────────────
  if (screen === 'run') {
    return (
      <Modal visible animationType="slide" onRequestClose={() => setScreen('list')}>
        <OutdoorRunView onDismiss={() => setScreen('list')} />
      </Modal>
    );
  }

  if (screen === 'detail' && selectedSession) {
    return (
      <SessionDetailView
        session={selectedSession}
        onBack={() => setScreen('list')}
        onEdit={() => setScreen('edit')}
        onDelete={() => handleDelete(selectedSession.id)}
      />
    );
  }

  if (screen === 'edit' && selectedSession) {
    return (
      <SessionEditorView
        initial={selectedSession}
        onSave={handleSaveEdit}
        onCancel={() => setScreen('detail')}
      />
    );
  }

  if (screen === 'newSession') {
    return (
      <SessionEditorView
        onSave={handleSaveNew}
        onCancel={() => setScreen('list')}
      />
    );
  }

  // ── Main list ─────────────────────────────────────────────────────────────────
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Workouts</Text>
        <View style={styles.headerBtns}>
          <TouchableOpacity style={styles.runBtn} onPress={() => setScreen('run')}>
            <Text style={styles.runBtnText}>Start Run</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.addBtn} onPress={() => setScreen('newSession')}>
            <Text style={styles.addBtnText}>+ Log</Text>
          </TouchableOpacity>
        </View>
      </View>

      {/* Filter pills */}
      <View style={styles.filterRow}>
        {FILTERS.map((f) => (
          <TouchableOpacity
            key={f.key}
            style={[styles.filterPill, filter === f.key && styles.filterPillActive]}
            onPress={() => setFilter(f.key)}
          >
            <Text style={[styles.filterLabel, filter === f.key && styles.filterLabelActive]}>
              {f.label}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      {/* Undo banner */}
      {pendingDelete && (
        <View style={styles.undoBanner}>
          <Text style={styles.undoText}>
            Session deleted. Shake to undo ({undoSecondsLeft}s)
          </Text>
          <TouchableOpacity onPress={() => { undoDelete(); }}>
            <Text style={styles.undoLink}>Undo</Text>
          </TouchableOpacity>
        </View>
      )}

      <FlatList
        data={filtered}
        keyExtractor={(s) => s.id}
        renderItem={({ item }) => (
          <SwipeableRow onDelete={() => handleDelete(item.id)}>
            <SessionRow
              session={item}
              onPress={() => {
                setSelectedSession(item);
                setScreen('detail');
              }}
            />
          </SwipeableRow>
        )}
        ListEmptyComponent={
          <Text style={styles.empty}>No sessions yet. Log a workout or start a run.</Text>
        }
        contentContainerStyle={styles.list}
      />
    </View>
  );
}

// ── Swipeable row (left swipe reveals delete) ────────────────────────────────

interface SwipeableProps {
  children: React.ReactNode;
  onDelete: () => void;
}

function SwipeableRow({ children, onDelete }: SwipeableProps): React.JSX.Element {
  const translateX = useRef(new Animated.Value(0)).current;
  const DELETE_THRESHOLD = -80;

  const panResponder = useRef(
    PanResponder.create({
      onMoveShouldSetPanResponder: (_, g) => Math.abs(g.dx) > 5 && g.dx < 0,
      onPanResponderMove: (_, g) => {
        if (g.dx < 0) translateX.setValue(Math.max(g.dx, -120));
      },
      onPanResponderRelease: (_, g) => {
        if (g.dx < DELETE_THRESHOLD) {
          Animated.timing(translateX, {
            toValue: -120,
            duration: 150,
            useNativeDriver: true,
          }).start(() => onDelete());
        } else {
          Animated.spring(translateX, {
            toValue: 0,
            useNativeDriver: true,
          }).start();
        }
      },
    })
  ).current;

  return (
    <View style={swipeStyles.container}>
      <View style={swipeStyles.deleteAction}>
        <Text style={swipeStyles.deleteText}>Delete</Text>
      </View>
      <Animated.View
        style={{ transform: [{ translateX }] }}
        {...panResponder.panHandlers}
      >
        {children}
      </Animated.View>
    </View>
  );
}

const swipeStyles = StyleSheet.create({
  container: { position: 'relative', overflow: 'hidden', marginBottom: 4 },
  deleteAction: {
    position: 'absolute',
    right: 0,
    top: 0,
    bottom: 0,
    width: 120,
    backgroundColor: COLORS.danger,
    borderRadius: RADIUS.md,
    alignItems: 'center',
    justifyContent: 'center',
  },
  deleteText: { color: COLORS.textInverse, fontWeight: FONT_WEIGHT.bold },
});

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: COLORS.background },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.md,
    backgroundColor: COLORS.surface,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
  },
  title: { fontSize: FONT_SIZE.xl, fontWeight: FONT_WEIGHT.bold, color: COLORS.text },
  headerBtns: { flexDirection: 'row', gap: SPACING.sm },
  runBtn: {
    backgroundColor: COLORS.primary,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.md,
  },
  runBtnText: { color: COLORS.textInverse, fontWeight: FONT_WEIGHT.semibold, fontSize: FONT_SIZE.sm },
  addBtn: {
    borderWidth: 1,
    borderColor: COLORS.primary,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.md,
  },
  addBtnText: { color: COLORS.primary, fontWeight: FONT_WEIGHT.semibold, fontSize: FONT_SIZE.sm },
  filterRow: {
    flexDirection: 'row',
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    gap: SPACING.xs,
    backgroundColor: COLORS.surface,
  },
  filterPill: {
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.full,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  filterPillActive: { backgroundColor: COLORS.primary, borderColor: COLORS.primary },
  filterLabel: { fontSize: FONT_SIZE.sm, color: COLORS.textSecondary },
  filterLabelActive: { color: COLORS.textInverse, fontWeight: FONT_WEIGHT.medium },
  undoBanner: {
    backgroundColor: COLORS.toast,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
  },
  undoText: { color: COLORS.textInverse, fontSize: FONT_SIZE.sm, flex: 1 },
  undoLink: { color: COLORS.primaryLight, fontWeight: FONT_WEIGHT.bold, marginLeft: SPACING.md },
  list: { paddingHorizontal: SPACING.md, paddingTop: SPACING.sm },
  empty: { textAlign: 'center', color: COLORS.textMuted, marginTop: SPACING.xl },
});
