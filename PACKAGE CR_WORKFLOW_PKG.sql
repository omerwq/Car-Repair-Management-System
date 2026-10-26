CREATE OR REPLACE PACKAGE CR_WORKFLOW_PKG AS
    FUNCTION HAS_ROLE(p_user VARCHAR2, p_role VARCHAR2) RETURN BOOLEAN;
    
    PROCEDURE TRANSITION_REQUEST(
        p_request_id IN NUMBER,
        p_action     IN VARCHAR2,
        p_actor      IN VARCHAR2,
        p_notes      IN VARCHAR2 DEFAULT NULL
    );
END CR_WORKFLOW_PKG;
/

CREATE OR REPLACE PACKAGE BODY CR_WORKFLOW_PKG AS

    -- 1. إضافة UPPER عشان نتجنب مشكلة الحروف الكبيرة والصغيرة
    FUNCTION HAS_ROLE(p_user VARCHAR2, p_role VARCHAR2) RETURN BOOLEAN IS
        l_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO l_count
        FROM CR_APP_USERS u
        JOIN CR_USER_ROLES ur ON UPPER(ur.USER_NAME) = UPPER(u.USER_NAME)
        JOIN CR_ROLES r ON r.ROLE_ID = ur.ROLE_ID
        WHERE UPPER(u.USER_NAME) = UPPER(p_user) 
          AND u.IS_ACTIVE = 'Y' 
          AND r.ROLE_CODE = p_role;
        RETURN l_count > 0;
    END HAS_ROLE;

    PROCEDURE TRANSITION_REQUEST(
        p_request_id IN NUMBER,
        p_action     IN VARCHAR2,
        p_actor      IN VARCHAR2,
        p_notes      IN VARCHAR2 DEFAULT NULL
    ) IS
        l_current_status VARCHAR2(30);
        l_next_status    VARCHAR2(30);
        l_required_role  VARCHAR2(30);
    BEGIN
        -- 2. إضافة MERGE عشان نتجنب مشكلة الـ Foreign Key (Parent key not found)
        MERGE INTO CR_APP_USERS t
        USING (SELECT UPPER(p_actor) AS user_name, 'System User' AS display_name, 'Y' AS is_active FROM dual) s
        ON (t.USER_NAME = s.user_name)
        WHEN NOT MATCHED THEN
            INSERT (USER_NAME, DISPLAY_NAME, IS_ACTIVE) VALUES (s.user_name, s.display_name, s.is_active);

        -- قفل الصف
        SELECT STATUS_CODE INTO l_current_status
        FROM CR_REQUEST
        WHERE REQUEST_ID = p_request_id
        FOR UPDATE;

        -- تحديد الـ Action
        IF p_action = 'SUBMIT_TO_ACCOUNTANT' THEN
            l_required_role := 'TECHNICIAN';
            l_next_status := 'AWAITING_ACCOUNTING';
            IF l_current_status NOT IN ('AWAITING_TECH_REVIEW', 'TECHNICIAN_REWORK') THEN
                raise_application_error(-20011, 'Invalid status for this action.');
            END IF;

        ELSIF p_action = 'ACCOUNTANT_APPROVE' THEN
            l_required_role := 'ACCOUNTANT';
            l_next_status := 'IN_MAINTENANCE';
            IF l_current_status != 'AWAITING_ACCOUNTING' THEN
                raise_application_error(-20012, 'Not awaiting accounting approval.');
            END IF;

        ELSIF p_action = 'ACCOUNTANT_REJECT' THEN
            l_required_role := 'ACCOUNTANT';
            l_next_status := 'TECHNICIAN_REWORK';
            IF l_current_status != 'AWAITING_ACCOUNTING' THEN
                raise_application_error(-20013, 'Not awaiting accounting approval.');
            END IF;
            IF TRIM(p_notes) IS NULL THEN
                raise_application_error(-20014, 'Rejection notes are mandatory.');
            END IF;

        ELSIF p_action = 'SEND_TO_QUALITY' THEN
            l_required_role := 'TECHNICIAN';
            l_next_status := 'AWAITING_QUALITY';
            IF l_current_status != 'IN_MAINTENANCE' THEN
                raise_application_error(-20015, 'Maintenance is not in progress.');
            END IF;

        ELSIF p_action = 'QUALITY_APPROVE' THEN
            l_required_role := 'QUALITY_REVIEWER';
            l_next_status := 'COMPLETED';
            IF l_current_status != 'AWAITING_QUALITY' THEN
                raise_application_error(-20016, 'Not awaiting quality review.');
            END IF;

        ELSIF p_action = 'QUALITY_REJECT' THEN
            l_required_role := 'QUALITY_REVIEWER';
            l_next_status := 'TECHNICIAN_REWORK';
            IF l_current_status != 'AWAITING_QUALITY' THEN
                raise_application_error(-20017, 'Not awaiting quality review.');
            END IF;
            IF TRIM(p_notes) IS NULL THEN
                raise_application_error(-20018, 'Reviewer notes are mandatory.');
            END IF;
            
        ELSE
            raise_application_error(-20019, 'Unknown workflow action.');
        END IF;

        -- التحقق من الصلاحية
        IF NOT HAS_ROLE(p_actor, l_required_role) THEN
            raise_application_error(-20010, 'You do not have permission to perform this action.');
        END IF;

        -- تحديث الطلب
        UPDATE CR_REQUEST
        SET STATUS_CODE = l_next_status,
            UPDATED_AT = SYSTIMESTAMP
        WHERE REQUEST_ID = p_request_id;

        -- 3. إضافة UPPER في تسجيل التاريخ
        INSERT INTO CR_REQUEST_HISTORY (
            REQUEST_ID, FROM_STATUS, TO_STATUS, ACTION_CODE, ACTOR_USER_NAME, NOTES
        ) VALUES (
            p_request_id, l_current_status, l_next_status, p_action, UPPER(p_actor), p_notes
        );

    END TRANSITION_REQUEST;

END CR_WORKFLOW_PKG;
/