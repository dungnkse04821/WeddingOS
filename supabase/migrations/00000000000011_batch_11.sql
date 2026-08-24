-- =============================================================================
-- BATCH-11: M5 Finance Core
-- =============================================================================

-- ---------------------------------------------------------------------------
-- SECTION 1: CORE TABLES
-- ---------------------------------------------------------------------------

CREATE TABLE public.budget_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id uuid NOT NULL REFERENCES public.weddings (id) ON DELETE CASCADE,
  wedding_event_id uuid,
  responsible_wedding_member_id uuid,
  name varchar(255) NOT NULL,
  estimated_cost numeric(15, 2),
  confirmed_cost numeric(15, 2),
  side varchar(50) NOT NULL DEFAULT 'COMMON',
  status varchar(50) NOT NULL DEFAULT 'ACTIVE',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_budget_items_estimated CHECK (estimated_cost >= 0),
  CONSTRAINT chk_budget_items_confirmed CHECK (confirmed_cost >= 0),
  CONSTRAINT chk_budget_items_side CHECK (side IN ('COMMON', 'BRIDE_SIDE', 'GROOM_SIDE')),
  CONSTRAINT chk_budget_items_status CHECK (status IN ('ACTIVE', 'CANCELLED', 'ARCHIVED')),
  CONSTRAINT fk_budget_items_responsible_wedding FOREIGN KEY (wedding_id, responsible_wedding_member_id) 
    REFERENCES public.wedding_members (wedding_id, id) ON DELETE SET NULL,
  CONSTRAINT fk_budget_items_event_wedding FOREIGN KEY (wedding_id, wedding_event_id) 
    REFERENCES public.wedding_events (wedding_id, id) ON DELETE RESTRICT
);

CREATE TABLE public.installments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  budget_item_id uuid NOT NULL REFERENCES public.budget_items (id) ON DELETE CASCADE,
  amount numeric(15, 2) NOT NULL,
  due_date date NOT NULL,
  status varchar(50) NOT NULL DEFAULT 'PENDING',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_installments_amount CHECK (amount > 0),
  CONSTRAINT chk_installments_status CHECK (status IN ('PENDING', 'PAID')),
  CONSTRAINT uq_installments_item_key UNIQUE (budget_item_id, id)
);

CREATE TABLE public.payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  budget_item_id uuid NOT NULL REFERENCES public.budget_items (id) ON DELETE RESTRICT,
  installment_id uuid,
  amount numeric(15, 2) NOT NULL,
  payment_date date NOT NULL,
  payer_display_name varchar(255) NOT NULL,
  payer_wedding_member_id uuid REFERENCES public.wedding_members (id) ON DELETE SET NULL,
  status varchar(50) NOT NULL DEFAULT 'ACTIVE',
  notes text,
  voided_at timestamptz,
  voided_by_user_id uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  void_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_payments_amount CHECK (amount > 0),
  CONSTRAINT chk_payments_status CHECK (status IN ('ACTIVE', 'VOIDED')),
  CONSTRAINT fk_payments_installment_item FOREIGN KEY (budget_item_id, installment_id) 
    REFERENCES public.installments (budget_item_id, id) ON DELETE RESTRICT
);

CREATE TABLE public.refunds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  budget_item_id uuid NOT NULL REFERENCES public.budget_items (id) ON DELETE RESTRICT,
  amount numeric(15, 2) NOT NULL,
  refund_date date NOT NULL,
  receiver varchar(100) NOT NULL,
  status varchar(50) NOT NULL DEFAULT 'ACTIVE',
  notes text,
  voided_at timestamptz,
  voided_by_user_id uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  void_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_refunds_amount CHECK (amount > 0),
  CONSTRAINT chk_refunds_status CHECK (status IN ('ACTIVE', 'VOIDED'))
);

-- ---------------------------------------------------------------------------
-- SECTION 2: UPDATED_AT TRIGGERS
-- ---------------------------------------------------------------------------

CREATE TRIGGER trg_budget_items_updated_at
  BEFORE UPDATE ON public.budget_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_payments_updated_at
  BEFORE UPDATE ON public.payments
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_refunds_updated_at
  BEFORE UPDATE ON public.refunds
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- SECTION 3: HISTORY GUARDS (DELETE TRIGGERS)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_budget_items_history_guard()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF current_user = 'trusted_function_owner' THEN
    RETURN OLD;
  END IF;

  IF EXISTS (SELECT 1 FROM public.installments WHERE budget_item_id = OLD.id) OR
     EXISTS (SELECT 1 FROM public.payments WHERE budget_item_id = OLD.id) OR
     EXISTS (SELECT 1 FROM public.refunds WHERE budget_item_id = OLD.id) THEN
    RAISE EXCEPTION 'Cannot delete budget item with financial history' USING ERRCODE = 'P0003';
  END IF;
  
  RETURN OLD;
END;
$$;

CREATE TRIGGER trg_budget_items_guard_delete
  BEFORE DELETE ON public.budget_items
  FOR EACH ROW EXECUTE FUNCTION public.trg_budget_items_history_guard();

CREATE OR REPLACE FUNCTION public.trg_installments_history_guard()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF current_user = 'trusted_function_owner' THEN
    RETURN OLD;
  END IF;

  IF EXISTS (SELECT 1 FROM public.payments WHERE installment_id = OLD.id) THEN
    RAISE EXCEPTION 'Cannot delete installment with payment history' USING ERRCODE = 'P0003';
  END IF;
  
  RETURN OLD;
END;
$$;

CREATE TRIGGER trg_installments_guard_delete
  BEFORE DELETE ON public.installments
  FOR EACH ROW EXECUTE FUNCTION public.trg_installments_history_guard();

-- Also block UPDATE on installment if history exists, unless via FIN-007
CREATE OR REPLACE FUNCTION public.trg_installments_update_guard()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF current_user = 'trusted_function_owner' THEN
    RETURN NEW;
  END IF;

  IF EXISTS (SELECT 1 FROM public.payments WHERE installment_id = OLD.id) THEN
    -- If amount or due date changes by client, deny
    IF OLD.amount IS DISTINCT FROM NEW.amount OR OLD.due_date IS DISTINCT FROM NEW.due_date THEN
       RAISE EXCEPTION 'Cannot update installment with payment history directly' USING ERRCODE = 'P0003';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_installments_guard_update
  BEFORE UPDATE ON public.installments
  FOR EACH ROW EXECUTE FUNCTION public.trg_installments_update_guard();


-- ---------------------------------------------------------------------------
-- SECTION 4: ROW-LEVEL SECURITY & GRANTS
-- ---------------------------------------------------------------------------

ALTER TABLE public.budget_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.installments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;

-- budget_items
CREATE POLICY select_budget_items ON public.budget_items
  FOR SELECT TO authenticated
  USING (security.is_wedding_owner(wedding_id));

CREATE POLICY insert_budget_items ON public.budget_items
  FOR INSERT TO authenticated
  WITH CHECK (security.can_owner_mutate_wedding(wedding_id));

CREATE POLICY update_budget_items ON public.budget_items
  FOR UPDATE TO authenticated
  USING (security.can_owner_mutate_wedding(wedding_id))
  WITH CHECK (security.can_owner_mutate_wedding(wedding_id));

CREATE POLICY delete_budget_items ON public.budget_items
  FOR DELETE TO authenticated
  USING (security.can_owner_mutate_wedding(wedding_id));

-- installments
-- Installments resolves wedding_id via budget_items
CREATE POLICY select_installments ON public.installments
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.budget_items bi
      WHERE bi.id = budget_item_id
        AND security.is_wedding_owner(bi.wedding_id)
    )
  );

CREATE POLICY insert_installments ON public.installments
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.budget_items bi
      WHERE bi.id = budget_item_id
        AND security.can_owner_mutate_wedding(bi.wedding_id)
    )
  );

CREATE POLICY update_installments ON public.installments
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.budget_items bi
      WHERE bi.id = budget_item_id
        AND security.can_owner_mutate_wedding(bi.wedding_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.budget_items bi
      WHERE bi.id = budget_item_id
        AND security.can_owner_mutate_wedding(bi.wedding_id)
    )
  );

CREATE POLICY delete_installments ON public.installments
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.budget_items bi
      WHERE bi.id = budget_item_id
        AND security.can_owner_mutate_wedding(bi.wedding_id)
    )
  );

-- payments (SELECT ONLY for authenticated client, CUD via RPC/trusted)
CREATE POLICY select_payments ON public.payments
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.budget_items bi
      WHERE bi.id = budget_item_id
        AND security.is_wedding_owner(bi.wedding_id)
    )
  );

-- refunds (SELECT ONLY for authenticated client, CUD via RPC/trusted)
CREATE POLICY select_refunds ON public.refunds
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.budget_items bi
      WHERE bi.id = budget_item_id
        AND security.is_wedding_owner(bi.wedding_id)
    )
  );

-- Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON public.budget_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.installments TO authenticated;

-- Payments/Refunds block CUD at GRANT level for safety
GRANT SELECT ON public.payments TO authenticated;
GRANT SELECT ON public.refunds TO authenticated;

-- trusted_function_owner gets all
GRANT SELECT, INSERT, UPDATE, DELETE ON public.budget_items TO trusted_function_owner;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.installments TO trusted_function_owner;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.payments TO trusted_function_owner;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.refunds TO trusted_function_owner;


-- ---------------------------------------------------------------------------
-- SECTION 5: INTERNAL HELPERS
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION internal.recompute_installment_status(p_installment_id uuid)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  v_installment public.installments%ROWTYPE;
  v_total_paid numeric(15,2);
BEGIN
  IF p_installment_id IS NULL THEN RETURN; END IF;

  SELECT * INTO v_installment FROM public.installments WHERE id = p_installment_id;
  IF NOT FOUND THEN RETURN; END IF;

  SELECT COALESCE(SUM(amount), 0) INTO v_total_paid
  FROM public.payments
  WHERE installment_id = p_installment_id AND status = 'ACTIVE';

  IF v_total_paid >= v_installment.amount THEN
    UPDATE public.installments SET status = 'PAID' WHERE id = p_installment_id AND status != 'PAID';
  ELSE
    UPDATE public.installments SET status = 'PENDING' WHERE id = p_installment_id AND status != 'PENDING';
  END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- SECTION 6: API_V1 PAYMENTS (FIN-001, 002, 003)
-- ---------------------------------------------------------------------------

-- FIN-001
CREATE OR REPLACE FUNCTION api_v1.create_payment(
  p_request_id uuid,
  p_budget_item_id uuid,
  p_installment_id uuid,
  p_amount numeric(15,2),
  p_payment_date date,
  p_payer_wedding_member_id uuid,
  p_payer_display_name varchar(255),
  p_notes text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_request_hash varchar(64);
  v_canonical text;
  v_existing_receipt private.trusted_operation_receipts%ROWTYPE;
  v_wedding_id uuid;
  v_budget_item public.budget_items%ROWTYPE;
  v_member public.wedding_members%ROWTYPE;
  v_final_payer_name varchar(255);
  v_payment_id uuid;
  v_payment public.payments%ROWTYPE;
BEGIN
  IF v_actor_id IS NULL THEN RAISE EXCEPTION 'UNAUTHORIZED' USING ERRCODE = 'P0001'; END IF;

  -- Validate BudgetItem & Wedding
  SELECT * INTO v_budget_item FROM public.budget_items WHERE id = p_budget_item_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_INPUT: budget_item not found' USING ERRCODE = 'P0002'; END IF;
  
  IF NOT security.can_owner_mutate_wedding(v_budget_item.wedding_id) THEN
    RAISE EXCEPTION 'UNAUTHORIZED: owner only' USING ERRCODE = 'P0001';
  END IF;

  -- Validate Installment
  IF p_installment_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.installments WHERE id = p_installment_id AND budget_item_id = p_budget_item_id) THEN
      RAISE EXCEPTION 'INVALID_INPUT: installment does not belong to budget item' USING ERRCODE = 'P0002';
    END IF;
  END IF;

  -- Validate Payer
  IF p_payer_wedding_member_id IS NOT NULL THEN
    SELECT * INTO v_member FROM public.wedding_members WHERE id = p_payer_wedding_member_id AND wedding_id = v_budget_item.wedding_id AND status = 'ACTIVE';
    IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_INPUT: payer member not active or not in wedding' USING ERRCODE = 'P0002'; END IF;
    v_final_payer_name := v_member.display_name;
  ELSE
    IF p_payer_display_name IS NULL OR trim(p_payer_display_name) = '' THEN
      RAISE EXCEPTION 'INVALID_INPUT: payer_display_name required for external payer' USING ERRCODE = 'P0002';
    END IF;
    v_final_payer_name := trim(p_payer_display_name);
  END IF;

  -- Canonical hash
  v_canonical := json_build_object(
    'amount', to_char(p_amount, 'FM9999999999999.00'),
    'budget_item_id', p_budget_item_id,
    'installment_id', p_installment_id,
    'notes', p_notes,
    'payer_display_name', CASE WHEN p_payer_wedding_member_id IS NULL THEN v_final_payer_name ELSE NULL END,
    'payer_wedding_member_id', p_payer_wedding_member_id,
    'payment_date', p_payment_date::text
  )::text;
  v_request_hash := encode(extensions.digest(v_canonical, 'sha256'), 'hex');

  -- Receipt
  SELECT * INTO v_existing_receipt FROM private.trusted_operation_receipts
  WHERE operation_type = 'TOP-FIN-001' AND actor_user_id = v_actor_id AND request_id = p_request_id;
  IF FOUND THEN
    IF v_existing_receipt.request_hash <> v_request_hash THEN
      RAISE EXCEPTION 'REQUEST_ID_REUSED' USING ERRCODE = '40900';
    END IF;
    SELECT * INTO v_payment FROM public.payments WHERE id = v_existing_receipt.result_resource_id;
    RETURN jsonb_build_object('replayed', true, 'payment', row_to_json(v_payment));
  END IF;

  -- Mutate
  INSERT INTO public.payments (budget_item_id, installment_id, amount, payment_date, payer_wedding_member_id, payer_display_name, notes, status)
  VALUES (p_budget_item_id, p_installment_id, p_amount, p_payment_date, p_payer_wedding_member_id, v_final_payer_name, p_notes, 'ACTIVE')
  RETURNING id INTO v_payment_id;

  INSERT INTO private.trusted_operation_receipts (operation_type, actor_user_id, request_id, wedding_id, request_hash, result_resource_id)
  VALUES ('TOP-FIN-001', v_actor_id, p_request_id, v_budget_item.wedding_id, v_request_hash, v_payment_id);

  PERFORM internal.recompute_installment_status(p_installment_id);

  SELECT * INTO v_payment FROM public.payments WHERE id = v_payment_id;
  RETURN jsonb_build_object('replayed', false, 'payment', row_to_json(v_payment));
END;
$$;

-- FIN-002
CREATE OR REPLACE FUNCTION api_v1.edit_payment(
  p_payment_id uuid,
  p_installment_id uuid,
  p_amount numeric(15,2),
  p_payment_date date,
  p_payer_wedding_member_id uuid,
  p_payer_display_name varchar(255),
  p_notes text,
  p_expected_updated_at timestamptz
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_payment public.payments%ROWTYPE;
  v_budget_item public.budget_items%ROWTYPE;
  v_member public.wedding_members%ROWTYPE;
  v_final_payer_name varchar(255);
  v_old_installment_id uuid;
BEGIN
  IF v_actor_id IS NULL THEN RAISE EXCEPTION 'UNAUTHORIZED' USING ERRCODE = 'P0001'; END IF;

  -- Lock payment
  SELECT * INTO v_payment FROM public.payments WHERE id = p_payment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_INPUT: payment not found' USING ERRCODE = 'P0002'; END IF;

  SELECT * INTO v_budget_item FROM public.budget_items WHERE id = v_payment.budget_item_id;
  IF NOT security.can_owner_mutate_wedding(v_budget_item.wedding_id) THEN
    RAISE EXCEPTION 'UNAUTHORIZED: owner only' USING ERRCODE = 'P0001';
  END IF;

  -- Validate Installment
  IF p_installment_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.installments WHERE id = p_installment_id AND budget_item_id = v_payment.budget_item_id) THEN
      RAISE EXCEPTION 'INVALID_INPUT: installment does not belong to budget item' USING ERRCODE = 'P0002';
    END IF;
  END IF;

  -- Validate Payer
  IF p_payer_wedding_member_id IS NOT NULL THEN
    SELECT * INTO v_member FROM public.wedding_members WHERE id = p_payer_wedding_member_id AND wedding_id = v_budget_item.wedding_id AND status = 'ACTIVE';
    IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_INPUT: payer member not active or not in wedding' USING ERRCODE = 'P0002'; END IF;
    v_final_payer_name := v_member.display_name;
  ELSE
    IF p_payer_display_name IS NULL OR trim(p_payer_display_name) = '' THEN
      RAISE EXCEPTION 'INVALID_INPUT: payer_display_name required for external payer' USING ERRCODE = 'P0002';
    END IF;
    v_final_payer_name := trim(p_payer_display_name);
  END IF;

  -- Check stale state or converged success
  IF v_payment.amount = p_amount AND v_payment.payment_date = p_payment_date AND v_payment.installment_id IS NOT DISTINCT FROM p_installment_id AND v_payment.payer_wedding_member_id IS NOT DISTINCT FROM p_payer_wedding_member_id AND v_payment.payer_display_name = v_final_payer_name AND v_payment.notes IS NOT DISTINCT FROM p_notes THEN
    RETURN jsonb_build_object('payment', row_to_json(v_payment));
  END IF;

  IF v_payment.updated_at <> p_expected_updated_at THEN
    RAISE EXCEPTION 'STALE_STATE' USING ERRCODE = '40901';
  END IF;

  v_old_installment_id := v_payment.installment_id;

  UPDATE public.payments SET
    installment_id = p_installment_id,
    amount = p_amount,
    payment_date = p_payment_date,
    payer_wedding_member_id = p_payer_wedding_member_id,
    payer_display_name = v_final_payer_name,
    notes = p_notes
  WHERE id = p_payment_id
  RETURNING * INTO v_payment;

  IF v_old_installment_id IS NOT NULL AND v_old_installment_id IS DISTINCT FROM p_installment_id THEN
    PERFORM internal.recompute_installment_status(v_old_installment_id);
  END IF;
  PERFORM internal.recompute_installment_status(p_installment_id);

  RETURN jsonb_build_object('payment', row_to_json(v_payment));
END;
$$;

-- FIN-003
CREATE OR REPLACE FUNCTION api_v1.void_payment(
  p_payment_id uuid,
  p_void_reason text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_payment public.payments%ROWTYPE;
  v_budget_item public.budget_items%ROWTYPE;
BEGIN
  IF v_actor_id IS NULL THEN RAISE EXCEPTION 'UNAUTHORIZED' USING ERRCODE = 'P0001'; END IF;

  SELECT * INTO v_payment FROM public.payments WHERE id = p_payment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_INPUT: payment not found' USING ERRCODE = 'P0002'; END IF;

  SELECT * INTO v_budget_item FROM public.budget_items WHERE id = v_payment.budget_item_id;
  IF NOT security.can_owner_mutate_wedding(v_budget_item.wedding_id) THEN
    RAISE EXCEPTION 'UNAUTHORIZED: owner only' USING ERRCODE = 'P0001';
  END IF;

  IF v_payment.status = 'VOIDED' THEN
    RETURN jsonb_build_object('payment', row_to_json(v_payment));
  END IF;

  UPDATE public.payments SET
    status = 'VOIDED',
    voided_at = now(),
    voided_by_user_id = v_actor_id,
    void_reason = p_void_reason
  WHERE id = p_payment_id
  RETURNING * INTO v_payment;

  PERFORM internal.recompute_installment_status(v_payment.installment_id);

  RETURN jsonb_build_object('payment', row_to_json(v_payment));
END;
$$;


-- ---------------------------------------------------------------------------
-- SECTION 7: API_V1 REFUNDS (FIN-004, 005, 006)
-- ---------------------------------------------------------------------------

-- FIN-004
CREATE OR REPLACE FUNCTION api_v1.create_refund(
  p_request_id uuid,
  p_budget_item_id uuid,
  p_amount numeric(15,2),
  p_refund_date date,
  p_receiver varchar(100),
  p_notes text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_request_hash varchar(64);
  v_canonical text;
  v_existing_receipt private.trusted_operation_receipts%ROWTYPE;
  v_budget_item public.budget_items%ROWTYPE;
  v_refund_id uuid;
  v_refund public.refunds%ROWTYPE;
BEGIN
  IF v_actor_id IS NULL THEN RAISE EXCEPTION 'UNAUTHORIZED' USING ERRCODE = 'P0001'; END IF;

  SELECT * INTO v_budget_item FROM public.budget_items WHERE id = p_budget_item_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_INPUT: budget_item not found' USING ERRCODE = 'P0002'; END IF;
  
  IF NOT security.can_owner_mutate_wedding(v_budget_item.wedding_id) THEN
    RAISE EXCEPTION 'UNAUTHORIZED: owner only' USING ERRCODE = 'P0001';
  END IF;

  v_canonical := json_build_object(
    'amount', to_char(p_amount, 'FM9999999999999.00'),
    'budget_item_id', p_budget_item_id,
    'notes', p_notes,
    'receiver', p_receiver,
    'refund_date', p_refund_date::text
  )::text;
  v_request_hash := encode(extensions.digest(v_canonical, 'sha256'), 'hex');

  SELECT * INTO v_existing_receipt FROM private.trusted_operation_receipts
  WHERE operation_type = 'TOP-FIN-004' AND actor_user_id = v_actor_id AND request_id = p_request_id;
  IF FOUND THEN
    IF v_existing_receipt.request_hash <> v_request_hash THEN
      RAISE EXCEPTION 'REQUEST_ID_REUSED' USING ERRCODE = '40900';
    END IF;
    SELECT * INTO v_refund FROM public.refunds WHERE id = v_existing_receipt.result_resource_id;
    RETURN jsonb_build_object('replayed', true, 'refund', row_to_json(v_refund));
  END IF;

  INSERT INTO public.refunds (budget_item_id, amount, refund_date, receiver, notes, status)
  VALUES (p_budget_item_id, p_amount, p_refund_date, p_receiver, p_notes, 'ACTIVE')
  RETURNING id INTO v_refund_id;

  INSERT INTO private.trusted_operation_receipts (operation_type, actor_user_id, request_id, wedding_id, request_hash, result_resource_id)
  VALUES ('TOP-FIN-004', v_actor_id, p_request_id, v_budget_item.wedding_id, v_request_hash, v_refund_id);

  SELECT * INTO v_refund FROM public.refunds WHERE id = v_refund_id;
  RETURN jsonb_build_object('replayed', false, 'refund', row_to_json(v_refund));
END;
$$;

-- FIN-005
CREATE OR REPLACE FUNCTION api_v1.edit_refund(
  p_refund_id uuid,
  p_amount numeric(15,2),
  p_refund_date date,
  p_receiver varchar(100),
  p_notes text,
  p_expected_updated_at timestamptz
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_refund public.refunds%ROWTYPE;
  v_budget_item public.budget_items%ROWTYPE;
BEGIN
  IF v_actor_id IS NULL THEN RAISE EXCEPTION 'UNAUTHORIZED' USING ERRCODE = 'P0001'; END IF;

  SELECT * INTO v_refund FROM public.refunds WHERE id = p_refund_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_INPUT: refund not found' USING ERRCODE = 'P0002'; END IF;

  SELECT * INTO v_budget_item FROM public.budget_items WHERE id = v_refund.budget_item_id;
  IF NOT security.can_owner_mutate_wedding(v_budget_item.wedding_id) THEN
    RAISE EXCEPTION 'UNAUTHORIZED: owner only' USING ERRCODE = 'P0001';
  END IF;

  IF v_refund.amount = p_amount AND v_refund.refund_date = p_refund_date AND v_refund.receiver = p_receiver AND v_refund.notes IS NOT DISTINCT FROM p_notes THEN
    RETURN jsonb_build_object('refund', row_to_json(v_refund));
  END IF;

  IF v_refund.updated_at <> p_expected_updated_at THEN
    RAISE EXCEPTION 'STALE_STATE' USING ERRCODE = '40901';
  END IF;

  UPDATE public.refunds SET
    amount = p_amount,
    refund_date = p_refund_date,
    receiver = p_receiver,
    notes = p_notes
  WHERE id = p_refund_id
  RETURNING * INTO v_refund;

  RETURN jsonb_build_object('refund', row_to_json(v_refund));
END;
$$;

-- FIN-006
CREATE OR REPLACE FUNCTION api_v1.void_refund(
  p_refund_id uuid,
  p_void_reason text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_refund public.refunds%ROWTYPE;
  v_budget_item public.budget_items%ROWTYPE;
BEGIN
  IF v_actor_id IS NULL THEN RAISE EXCEPTION 'UNAUTHORIZED' USING ERRCODE = 'P0001'; END IF;

  SELECT * INTO v_refund FROM public.refunds WHERE id = p_refund_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_INPUT: refund not found' USING ERRCODE = 'P0002'; END IF;

  SELECT * INTO v_budget_item FROM public.budget_items WHERE id = v_refund.budget_item_id;
  IF NOT security.can_owner_mutate_wedding(v_budget_item.wedding_id) THEN
    RAISE EXCEPTION 'UNAUTHORIZED: owner only' USING ERRCODE = 'P0001';
  END IF;

  IF v_refund.status = 'VOIDED' THEN
    RETURN jsonb_build_object('refund', row_to_json(v_refund));
  END IF;

  UPDATE public.refunds SET
    status = 'VOIDED',
    voided_at = now(),
    voided_by_user_id = v_actor_id,
    void_reason = p_void_reason
  WHERE id = p_refund_id
  RETURNING * INTO v_refund;

  RETURN jsonb_build_object('refund', row_to_json(v_refund));
END;
$$;

-- ---------------------------------------------------------------------------
-- SECTION 8: API_V1 INSTALLMENT COMPOUND (FIN-007)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api_v1.preview_installment_compound(
  p_installment_id uuid,
  p_new_amount numeric(15,2) DEFAULT NULL,
  p_new_due_date date DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_installment public.installments%ROWTYPE;
  v_budget_item public.budget_items%ROWTYPE;
  v_proposed_amount numeric(15,2);
  v_proposed_due_date date;
  v_linked_active_amount numeric(15,2) := 0;
  v_linked_history_count integer := 0;
  v_remaining_before numeric(15,2);
  v_remaining_after numeric(15,2);
  v_status_before varchar(50);
  v_status_after varchar(50);
  v_warning_flags jsonb := '[]'::jsonb;
  v_impact_fingerprint varchar(64);
  v_history_hash text;
BEGIN
  IF v_actor_id IS NULL THEN RAISE EXCEPTION 'UNAUTHORIZED' USING ERRCODE = 'P0001'; END IF;

  SELECT * INTO v_installment FROM public.installments WHERE id = p_installment_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_INPUT: installment not found' USING ERRCODE = 'P0002'; END IF;

  SELECT * INTO v_budget_item FROM public.budget_items WHERE id = v_installment.budget_item_id;
  IF NOT security.can_owner_mutate_wedding(v_budget_item.wedding_id) THEN
    RAISE EXCEPTION 'UNAUTHORIZED: owner only' USING ERRCODE = 'P0001';
  END IF;

  v_proposed_amount := COALESCE(p_new_amount, v_installment.amount);
  v_proposed_due_date := COALESCE(p_new_due_date, v_installment.due_date);

  IF v_proposed_amount <= 0 THEN
    RAISE EXCEPTION 'INVALID_INPUT: amount must be > 0' USING ERRCODE = 'P0002';
  END IF;

  SELECT COALESCE(SUM(amount), 0), COUNT(id)
  INTO v_linked_active_amount, v_linked_history_count
  FROM public.payments
  WHERE installment_id = p_installment_id AND status = 'ACTIVE';

  v_remaining_before := GREATEST(v_installment.amount - v_linked_active_amount, 0);
  v_remaining_after := GREATEST(v_proposed_amount - v_linked_active_amount, 0);

  v_status_before := v_installment.status;
  IF v_linked_active_amount >= v_proposed_amount THEN
    v_status_after := 'PAID';
  ELSE
    v_status_after := 'PENDING';
  END IF;

  IF v_linked_active_amount > v_proposed_amount THEN
    v_warning_flags := '["PAYMENT_EXCEEDS_INSTALLMENT"]'::jsonb;
  END IF;

  -- Deterministic history string
  SELECT string_agg(id::text || '_' || to_char(amount, 'FM9999999999999.00') || '_' || to_char(payment_date, 'YYYY-MM-DD') || '_' || status, ',' ORDER BY id)
  INTO v_history_hash
  FROM public.payments
  WHERE installment_id = p_installment_id;

  v_impact_fingerprint := encode(extensions.digest(
    v_installment.id::text || '_' || v_installment.budget_item_id::text || '_' ||
    to_char(v_installment.amount, 'FM9999999999999.00') || '_' || to_char(v_installment.due_date, 'YYYY-MM-DD') || '_' ||
    v_installment.status || '_' || COALESCE(v_history_hash, 'NONE'),
    'sha256'
  ), 'hex');

  RETURN jsonb_build_object(
    'installment_id', p_installment_id,
    'current_amount', to_char(v_installment.amount, 'FM9999999999999.00'),
    'proposed_amount', to_char(v_proposed_amount, 'FM9999999999999.00'),
    'current_due_date', to_char(v_installment.due_date, 'YYYY-MM-DD'),
    'proposed_due_date', to_char(v_proposed_due_date, 'YYYY-MM-DD'),
    'linked_financial_history_count', v_linked_history_count,
    'linked_active_payment_amount', to_char(v_linked_active_amount, 'FM9999999999999.00'),
    'remaining_before', to_char(v_remaining_before, 'FM9999999999999.00'),
    'remaining_after', to_char(v_remaining_after, 'FM9999999999999.00'),
    'derived_status_before', v_status_before,
    'derived_status_after', v_status_after,
    'warning_flags', v_warning_flags,
    'impact_fingerprint', v_impact_fingerprint
  );
END;
$$;

CREATE OR REPLACE FUNCTION api_v1.commit_installment_compound(
  p_installment_id uuid,
  p_impact_fingerprint varchar(64),
  p_new_amount numeric(15,2) DEFAULT NULL,
  p_new_due_date date DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_installment public.installments%ROWTYPE;
  v_budget_item public.budget_items%ROWTYPE;
  v_proposed_amount numeric(15,2);
  v_proposed_due_date date;
  v_linked_active_amount numeric(15,2);
  v_status_after varchar(50);
  v_history_hash text;
  v_current_fingerprint varchar(64);
BEGIN
  IF v_actor_id IS NULL THEN RAISE EXCEPTION 'UNAUTHORIZED' USING ERRCODE = 'P0001'; END IF;

  SELECT * INTO v_installment FROM public.installments WHERE id = p_installment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_INPUT: installment not found' USING ERRCODE = 'P0002'; END IF;

  SELECT * INTO v_budget_item FROM public.budget_items WHERE id = v_installment.budget_item_id;
  IF NOT security.can_owner_mutate_wedding(v_budget_item.wedding_id) THEN
    RAISE EXCEPTION 'UNAUTHORIZED: owner only' USING ERRCODE = 'P0001';
  END IF;

  v_proposed_amount := COALESCE(p_new_amount, v_installment.amount);
  v_proposed_due_date := COALESCE(p_new_due_date, v_installment.due_date);

  IF v_proposed_amount <= 0 THEN
    RAISE EXCEPTION 'INVALID_INPUT: amount must be > 0' USING ERRCODE = 'P0002';
  END IF;

  IF v_installment.amount = v_proposed_amount AND v_installment.due_date = v_proposed_due_date THEN
    RETURN jsonb_build_object('installment', row_to_json(v_installment));
  END IF;

  -- Recompute fingerprint
  SELECT string_agg(id::text || '_' || to_char(amount, 'FM9999999999999.00') || '_' || to_char(payment_date, 'YYYY-MM-DD') || '_' || status, ',' ORDER BY id)
  INTO v_history_hash
  FROM public.payments
  WHERE installment_id = p_installment_id;

  v_current_fingerprint := encode(extensions.digest(
    v_installment.id::text || '_' || v_installment.budget_item_id::text || '_' ||
    to_char(v_installment.amount, 'FM9999999999999.00') || '_' || to_char(v_installment.due_date, 'YYYY-MM-DD') || '_' ||
    v_installment.status || '_' || COALESCE(v_history_hash, 'NONE'),
    'sha256'
  ), 'hex');

  IF v_current_fingerprint <> p_impact_fingerprint THEN
    RAISE EXCEPTION 'STALE_IMPACT' USING ERRCODE = '40901';
  END IF;

  SELECT COALESCE(SUM(amount), 0) INTO v_linked_active_amount
  FROM public.payments WHERE installment_id = p_installment_id AND status = 'ACTIVE';

  IF v_linked_active_amount >= v_proposed_amount THEN
    v_status_after := 'PAID';
  ELSE
    v_status_after := 'PENDING';
  END IF;

  UPDATE public.installments SET
    amount = v_proposed_amount,
    due_date = v_proposed_due_date,
    status = v_status_after
  WHERE id = p_installment_id
  RETURNING * INTO v_installment;

  RETURN jsonb_build_object('installment', row_to_json(v_installment));
END;
$$;


-- ---------------------------------------------------------------------------
-- SECTION 9: FUNCTION OWNERSHIP & GRANTS
-- ---------------------------------------------------------------------------

ALTER FUNCTION internal.recompute_installment_status(uuid) OWNER TO trusted_function_owner;

ALTER FUNCTION api_v1.create_payment(uuid, uuid, uuid, numeric, date, uuid, varchar, text) OWNER TO trusted_function_owner;
REVOKE EXECUTE ON FUNCTION api_v1.create_payment(uuid, uuid, uuid, numeric, date, uuid, varchar, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api_v1.create_payment(uuid, uuid, uuid, numeric, date, uuid, varchar, text) TO authenticated;

ALTER FUNCTION api_v1.edit_payment(uuid, uuid, numeric, date, uuid, varchar, text, timestamptz) OWNER TO trusted_function_owner;
REVOKE EXECUTE ON FUNCTION api_v1.edit_payment(uuid, uuid, numeric, date, uuid, varchar, text, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api_v1.edit_payment(uuid, uuid, numeric, date, uuid, varchar, text, timestamptz) TO authenticated;

ALTER FUNCTION api_v1.void_payment(uuid, text) OWNER TO trusted_function_owner;
REVOKE EXECUTE ON FUNCTION api_v1.void_payment(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api_v1.void_payment(uuid, text) TO authenticated;

ALTER FUNCTION api_v1.create_refund(uuid, uuid, numeric, date, varchar, text) OWNER TO trusted_function_owner;
REVOKE EXECUTE ON FUNCTION api_v1.create_refund(uuid, uuid, numeric, date, varchar, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api_v1.create_refund(uuid, uuid, numeric, date, varchar, text) TO authenticated;

ALTER FUNCTION api_v1.edit_refund(uuid, numeric, date, varchar, text, timestamptz) OWNER TO trusted_function_owner;
REVOKE EXECUTE ON FUNCTION api_v1.edit_refund(uuid, numeric, date, varchar, text, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api_v1.edit_refund(uuid, numeric, date, varchar, text, timestamptz) TO authenticated;

ALTER FUNCTION api_v1.void_refund(uuid, text) OWNER TO trusted_function_owner;
REVOKE EXECUTE ON FUNCTION api_v1.void_refund(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api_v1.void_refund(uuid, text) TO authenticated;

ALTER FUNCTION api_v1.preview_installment_compound(uuid, numeric, date) OWNER TO trusted_function_owner;
REVOKE EXECUTE ON FUNCTION api_v1.preview_installment_compound(uuid, numeric, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api_v1.preview_installment_compound(uuid, numeric, date) TO authenticated;

ALTER FUNCTION api_v1.commit_installment_compound(uuid, varchar, numeric, date) OWNER TO trusted_function_owner;
REVOKE EXECUTE ON FUNCTION api_v1.commit_installment_compound(uuid, varchar, numeric, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api_v1.commit_installment_compound(uuid, varchar, numeric, date) TO authenticated;


-- ---------------------------------------------------------------------------
-- SECTION 10: FINANCE AGGREGATES (VIEW)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW public.finance_summaries WITH (security_invoker = true) AS
WITH item_paid AS (
  SELECT b.id AS budget_item_id,
         COALESCE(SUM(CASE WHEN pr.type = 'payment' THEN pr.amount ELSE -pr.amount END), 0) AS net_paid
  FROM public.budget_items b
  LEFT JOIN (
    SELECT budget_item_id, amount, 'payment' as type FROM public.payments WHERE status = 'ACTIVE'
    UNION ALL
    SELECT budget_item_id, amount, 'refund' as type FROM public.refunds WHERE status = 'ACTIVE'
  ) pr ON b.id = pr.budget_item_id
  GROUP BY b.id
),
wedding_metrics AS (
  SELECT b.wedding_id,
         COALESCE(SUM(ip.net_paid), 0) AS net_paid,
         SUM(COALESCE(b.confirmed_cost, b.estimated_cost, 0)) AS total_projected,
         SUM(b.confirmed_cost) AS total_confirmed,
         SUM(GREATEST(b.confirmed_cost - ip.net_paid, 0)) AS outstanding,
         SUM(GREATEST(ip.net_paid - b.confirmed_cost, 0)) AS overpaid,
         COUNT(CASE WHEN b.confirmed_cost IS NULL THEN 1 END) AS unknown_outstanding_count
  FROM public.budget_items b
  LEFT JOIN item_paid ip ON b.id = ip.budget_item_id
  GROUP BY b.wedding_id
),
upcoming AS (
  SELECT b.wedding_id,
         SUM(CASE WHEN i.due_date BETWEEN current_date AND current_date + 7 THEN GREATEST(i.amount - COALESCE(ip.paid, 0), 0) ELSE 0 END) AS upcoming_7d,
         SUM(CASE WHEN i.due_date BETWEEN current_date AND current_date + 30 THEN GREATEST(i.amount - COALESCE(ip.paid, 0), 0) ELSE 0 END) AS upcoming_30d
  FROM public.installments i
  JOIN public.budget_items b ON i.budget_item_id = b.id
  LEFT JOIN (
    SELECT installment_id, SUM(amount) AS paid FROM public.payments WHERE status = 'ACTIVE' GROUP BY installment_id
  ) ip ON i.id = ip.installment_id
  WHERE i.status != 'PAID'
  GROUP BY b.wedding_id
)
SELECT 
  w.id AS wedding_id,
  w.target_budget,
  COALESCE(wm.total_projected, 0)::numeric(15,2) AS total_projected,
  COALESCE(wm.total_confirmed, 0)::numeric(15,2) AS total_confirmed,
  COALESCE(wm.net_paid, 0)::numeric(15,2) AS net_paid,
  (CASE WHEN wm.unknown_outstanding_count > 0 THEN NULL ELSE COALESCE(wm.outstanding, 0) END)::numeric(15,2) AS outstanding,
  COALESCE(wm.overpaid, 0)::numeric(15,2) AS overpaid,
  COALESCE(u.upcoming_7d, 0)::numeric(15,2) AS upcoming_7d,
  COALESCE(u.upcoming_30d, 0)::numeric(15,2) AS upcoming_30d
FROM public.weddings w
LEFT JOIN wedding_metrics wm ON w.id = wm.wedding_id
LEFT JOIN upcoming u ON w.id = u.wedding_id
WHERE security.is_wedding_owner(w.id);


GRANT SELECT ON public.finance_summaries TO authenticated;
